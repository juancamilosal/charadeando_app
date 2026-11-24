import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/bomb_explosion.dart';
import '../widgets/countdown_view.dart';
import '../widgets/letter_wheel.dart';
import '../widgets/play_background.dart';
import '../widgets/result_parts.dart';
import '../widgets/system_back.dart';

enum _Phase {
  loading,
  error,
  ready,
  countdown,
  playing,
  roundOver,
  boom,
  result,
}

/// El juego "La Bomba" (por dentro, Letras). Sale una temática con su
/// rueda de letras; quien tiene el celular dice una palabra de la temática,
/// toca la letra con que empieza (queda usada) y se lo pasa al siguiente.
/// Cuando se usan todas las letras termina la ronda: se pausa la bomba,
/// avisa "Ronda 1 finalizada" y en la siguiente hay que decir una palabra
/// más. La bomba explota en un tiempo secreto (de 20 a 60 segundos):
/// pierde quien la tenía. Todo en vertical, y si "Grabar video" está
/// encendido, graba con la cámara de frente a quien tiene el celular, con
/// la temática, cada letra elegida, los avisos de ronda y la explosión.
class LettersScreen extends ConsumerStatefulWidget {
  const LettersScreen({super.key, this.random, this.startWith});

  /// Para las pruebas.
  final Random? random;

  /// Para las pruebas y las capturas: empieza con estas temáticas, sin
  /// pedirlas al servidor.
  final List<LettersTopic>? startWith;

  @override
  ConsumerState<LettersScreen> createState() => _LettersScreenState();
}

class _LettersScreenState extends ConsumerState<LettersScreen>
    with WidgetsBindingObserver {
  late final _random = widget.random ?? Random();
  _Phase _phase = _Phase.loading;
  LettersGame? _game;
  Object? _error;

  /// Tiempo que lleva corriendo la bomba actual (se detiene entre rondas).
  final _clock = Stopwatch();

  /// Tiempo del video de la bomba actual (no se detiene).
  final _videoClock = Stopwatch();

  /// Para el video: cuándo se eligió cada letra y los avisos de ronda.
  final _picks = <(Duration, String)>[];
  final _notices = <(Duration, Duration, String)>[];
  Duration? _noticeFrom;

  /// Cómo explota la bomba: en secreto (como siempre) o a los 11 segundos
  /// de cada quien. "Otra bomba" sigue con el mismo.
  LettersMode _mode = LettersMode.secret;

  /// En el modo de 11 segundos: el tiempo que le queda a quien tiene el
  /// celular. Lo baja un temporizador cada décima; en cero, ¡BOOM!
  Duration _turnLeft = LettersRules.turnTime;
  Timer? _turnTimer;

  /// La cuenta 3, 2, 1 antes de cada bomba, como en las categorías.
  static const _countdownFrom = 3;
  int _countdown = _countdownFrom;
  Timer? _countdownTimer;

  /// La bomba late con cada tic.
  bool _pulse = false;
  Timer? _tickTimer;
  Timer? _fuseTimer;

  /// "¡Pasa el celular!" se ve un momento después de cada pase.
  bool _passFlash = false;
  Timer? _flashTimer;

  /// Medio segundo después de un pase no cuenta otro.
  Timer? _passCooldown;

  /// La temática que escribió el grupo en la última bomba ("Escribir temática");
  /// null si fue rápida (al azar). "Otra bomba" sigue igual.
  String? _custom;

  CameraController? _camera;
  bool _recording = false;

  /// Si se grabó video en alguna bomba (para las estadísticas).
  bool _recorded = false;

  /// Al salir ya no se puede usar `ref`: se guarda al entrar.
  late final StatsService _stats;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stats = ref.read(statsServiceProvider);
    ScreenOrientation.portrait().ignore();
    _load();
    if (ref.read(settingsProvider).recordVideo) _openCamera();
  }

  Future<void> _load() async {
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    try {
      final topics =
          widget.startWith ??
          await ref
              .read(lettersBankProvider)
              .prepare(
                includePremium:
                    LettersBank.freeForNow || ref.read(premiumUnlockedProvider),
              );
      if (!mounted) return;
      setState(() {
        _game = LettersGame(topics, random: _random);
        _phase = _Phase.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _phase = _Phase.error;
      });
    }
  }

  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final camera = CameraController(front, ResolutionPreset.high);
      await camera.initialize();
      await camera.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await camera.prepareForVideoRecording();
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() => _camera = camera);
    } catch (e) {
      // Sin cámara (o sin permiso) se juega igual, sin video.
      debugPrint('[Letras] Sin cámara: $e');
    }
  }

  /// Saca la temática (al azar, o [custom] si el grupo la escribió) y
  /// arranca la bomba.
  void _spin({String? custom}) {
    final game = _game ??= LettersGame(const [], random: _random);
    if (custom == null && !game.hasTopics) return;
    _custom = custom;
    ref.read(turnVideoProvider.notifier).discard().ignore();
    game.nextBomb(custom: custom);
    _picks.clear();
    _notices.clear();
    ref.read(hapticsProvider).heavy();
    _startCountdown();
  }

  /// "Escribir temática": el grupo escribe la temática y arranca la bomba.
  Future<void> _playCustom() async {
    final topic = await showDialog<String>(
      context: context,
      builder: (_) => _TopicDialog(initial: _custom ?? ''),
    );
    if (!mounted || topic == null || topic.trim().isEmpty) return;
    _spin(custom: topic.trim());
  }

  // --- La bomba ------------------------------------------------------------

  /// 3, 2, 1 con un pitido en cada número (y la temática arriba), para
  /// alcanzar a prepararse; luego arranca la bomba.
  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdown = _countdownFrom;
      _phase = _Phase.countdown;
    });
    final sounds = ref.read(soundServiceProvider);
    sounds.play(SoundEffect.countdown);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _phase != _Phase.countdown) {
        timer.cancel();
      } else if (_countdown > 1) {
        setState(() => _countdown--);
        sounds.play(SoundEffect.countdown);
      } else {
        timer.cancel();
        sounds.play(SoundEffect.start);
        _start();
      }
    });
  }

  Future<void> _start() async {
    if (!mounted) return;
    final game = _game!;
    setState(() => _phase = _Phase.playing);
    final camera = _camera;
    if (camera != null && camera.value.isInitialized) {
      try {
        await camera.startVideoRecording();
        _recording = true;
        _recorded = true;
      } catch (e) {
        debugPrint('[Letras] No se pudo grabar: $e');
      }
    }
    _clock
      ..reset()
      ..start();
    _videoClock
      ..reset()
      ..start();
    if (_mode == LettersMode.turn) {
      _startTurn();
    } else {
      _fuseTimer = Timer(game.fuse, _explode);
    }
    _tick();
    if (mounted) setState(() {});
  }

  /// Modo de 11 segundos: empieza el tiempo de quien tiene el celular. Si
  /// se le acaba, ¡BOOM!
  void _startTurn() {
    _turnTimer?.cancel();
    setState(() => _turnLeft = LettersRules.turnTime);
    const step = Duration(milliseconds: 100);
    _turnTimer = Timer.periodic(step, (timer) {
      if (!mounted || _phase != _Phase.playing) return;
      final left = _turnLeft - step;
      if (left <= Duration.zero) {
        timer.cancel();
        _turnLeft = Duration.zero;
        _explode();
      } else {
        setState(() => _turnLeft = left);
      }
    });
  }

  /// Segundos que le quedan a quien tiene el celular (modo de 11 s).
  int get _secondsLeft => (_turnLeft.inMilliseconds / 1000).ceil();

  void _stopTurn() {
    _turnTimer?.cancel();
    _turnTimer = null;
  }

  /// El tic-tac, cada vez más rápido.
  void _tick() {
    final game = _game;
    if (!mounted || _phase != _Phase.playing || game == null) return;
    ref.read(soundServiceProvider).play(SoundEffect.tick);
    // En el modo de 11 segundos el tic-tac se acelera en cada turno.
    _tickTimer = Timer(
      _mode == LettersMode.turn
          ? LettersRules.tickInterval(
              LettersRules.turnTime - _turnLeft,
              LettersRules.turnTime,
            )
          : LettersRules.tickInterval(_clock.elapsed, game.fuse),
      _tick,
    );
    setState(() => _pulse = !_pulse);
  }

  /// Se dijo una palabra con [letter]: queda usada y se pasa el celular.
  void _choose(String letter) {
    if (_phase != _Phase.playing) return;
    // Un toque cada medio segundo como mucho: si no, dos toques seguidos
    // contarían dos pases.
    if (_passCooldown?.isActive ?? false) return;
    final game = _game!;
    if (game.used.contains(letter)) return;
    _passCooldown = Timer(const Duration(milliseconds: 500), () {});
    final roundOver = game.choose(letter);
    _picks.add((_videoClock.elapsed, letter));
    ref.read(hapticsProvider).heavy();
    ref.read(soundServiceProvider).play(SoundEffect.hit);
    _flashTimer?.cancel();
    if (roundOver) {
      _pauseBomb();
      return;
    }
    // El siguiente tiene sus 11 segundos.
    if (_mode == LettersMode.turn) _startTurn();
    setState(() => _passFlash = true);
    _flashTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _passFlash = false);
    });
  }

  /// Se usaron todas las letras: la bomba se detiene y sale el aviso.
  void _pauseBomb() {
    _fuseTimer?.cancel();
    _tickTimer?.cancel();
    _clock.stop();
    _stopTurn();
    _noticeFrom = _videoClock.elapsed;
    setState(() {
      _passFlash = false;
      _phase = _Phase.roundOver;
    });
  }

  /// "¡Seguir!": letras libres otra vez y la bomba sigue donde iba.
  void _nextRound() {
    final game = _game!;
    final from = _noticeFrom;
    if (from != null) {
      _notices.add((from, _videoClock.elapsed, _roundNotice(game.round)));
    }
    game.nextRound();
    setState(() => _phase = _Phase.playing);
    _clock.start();
    if (_mode == LettersMode.turn) {
      _startTurn();
    } else {
      final left = game.fuse - _clock.elapsed;
      _fuseTimer = Timer(left.isNegative ? Duration.zero : left, _explode);
    }
    _tick();
  }

  /// "Ronda 1 finalizada · Ahora, dos palabras" (para el video).
  static String _roundNotice(int round) =>
      'Ronda $round finalizada · Ahora, '
      '${LettersGame.number(round + 1)} palabras';

  Future<void> _explode() async {
    if (!mounted || _phase != _Phase.playing) return;
    _tickTimer?.cancel();
    _clock.stop();
    _stopTurn();
    final game = _game!;
    // En el modo de 11 segundos la bomba duró lo que se jugó.
    if (_mode == LettersMode.turn) game.fuse = _clock.elapsed;
    final bomb = game.explode();
    setState(() => _phase = _Phase.boom);
    ref.read(soundServiceProvider).play(SoundEffect.boom);
    final haptics = ref.read(hapticsProvider);
    for (var i = 0; i < 4; i++) {
      Timer(Duration(milliseconds: i * 180), haptics.heavy);
    }
    ref.read(lettersBankProvider).remember(bomb.topic).ignore();
    // El video sigue un momento después del BOOM, para ver las caras.
    final boomAt = _videoClock.elapsed;
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    await _finishVideo(bomb, boomAt, _videoClock.elapsed);
    _videoClock.stop();
    if (mounted && _phase == _Phase.boom) {
      setState(() => _phase = _Phase.result);
    }
  }

  Future<void> _finishVideo(
    LettersBomb bomb,
    Duration boomAt,
    Duration recorded,
  ) async {
    final camera = _camera;
    if (!_recording || camera == null) return;
    _recording = false;
    try {
      final file = await camera.stopVideoRecording();
      final subtitles = VideoRenderer.lettersSubtitles(
        topic: bomb.topic.topic,
        picks: [..._picks],
        notices: [..._notices],
        boomAt: boomAt,
        end: recorded,
        letters: LettersRules.letters,
      );
      ref
          .read(turnVideoProvider.notifier)
          .process(
            TurnRecording(
              segments: [file.path],
              captions: const [],
              duration: recorded,
            ),
            VideoResolution.hd,
            subtitles: subtitles,
            describe: (assetId) => SavedVideo(
              assetId: assetId,
              savedAt: DateTime.now(),
              category: 'La Bomba: ${bomb.topic.topic}',
              round: game.bombs.length,
              points: bomb.passes,
            ),
          )
          .ignore();
    } catch (e) {
      debugPrint('[Letras] No se pudo terminar el video: $e');
    }
  }

  LettersGame get game => _game!;

  /// Corta la bomba sin explotar (se salió de la app o del juego).
  Future<void> _abort() async {
    _countdownTimer?.cancel();
    _stopTurn();
    _tickTimer?.cancel();
    _fuseTimer?.cancel();
    _clock.stop();
    final camera = _camera;
    if (_recording && camera != null) {
      _recording = false;
      try {
        await camera.stopVideoRecording();
      } catch (_) {}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    if (_phase == _Phase.countdown ||
        _phase == _Phase.playing ||
        _phase == _Phase.roundOver) {
      _abort();
      if (mounted) setState(() => _phase = _Phase.ready);
    }
  }

  Future<void> _exit() async {
    await _abort();
    if (mounted) context.go(Routes.categories);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _turnTimer?.cancel();
    _tickTimer?.cancel();
    _fuseTimer?.cancel();
    _flashTimer?.cancel();
    _passCooldown?.cancel();
    _camera?.dispose();
    final game = _game;
    if (game != null && game.bombs.isNotEmpty) {
      _stats
          .recordLetters(
            bombs: game.bombs.length,
            passes: game.totalPasses,
            averageFuse: game.averageFuse,
            video: _recorded,
          )
          .ignore();
    }
    super.dispose();
  }

  // --- Pantallas ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SystemBack(
      onBack: _exit,
      child: PlayBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: switch (_phase) {
                    _Phase.loading => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    _Phase.error => _errorView(),
                    _Phase.ready => _readyView(),
                    // La cuenta va encima de todo (abajo).
                    _Phase.countdown => const SizedBox.expand(),
                    _Phase.playing || _Phase.boom => _bombView(),
                    _Phase.roundOver => _roundOverView(),
                    _Phase.result => _resultView(),
                  },
                ),
              ),
              if (_phase == _Phase.countdown)
                Positioned.fill(
                  child: CountdownView(
                    value: _countdown,
                    caption: _game?.topic?.topic,
                  ),
                ),
              if (_phase == _Phase.boom)
                Positioned.fill(
                  child: BombExplosion(
                    letters: _game?.letters ?? const [],
                    used: {...?_game?.used},
                  ),
                ),
              if (_phase != _Phase.boom)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 4,
                  left: 4,
                  child: IconButton(
                    tooltip: 'Salir',
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _exit,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorView() {
    final error = _error;
    final message = switch (error) {
      LettersException() => error.message,
      DirectusException() => error.userMessage,
      _ => 'Inténtalo otra vez en un momento.',
    };
    final offline = error is LettersException && error.offline;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            offline ? Icons.wifi_off : Icons.cloud_off,
            color: Colors.white,
            size: 64,
          ),
          const SizedBox(height: 12),
          Text(
            offline ? 'Sin conexión' : 'No se pudieron traer las temáticas',
            textAlign: TextAlign.center,
            style: _title(28),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _load, child: const Text('Reintentar')),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _playCustom,
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text(
              'Escribir temática',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readyView() {
    final settings = ref.watch(settingsProvider);
    return Column(
      children: [
        // Si no cabe (celulares pequeños), se desplaza; el interruptor
        // queda siempre abajo.
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 32),
                const Text('💣', style: TextStyle(fontSize: 88)),
                Text(
                  'La Bomba',
                  textAlign: TextAlign.center,
                  style: _title(52),
                ),
                const SizedBox(height: 8),
                Text(
                  'Di una palabra, toca su letra y ¡pásala!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                _BombModePicker(
                  mode: _mode,
                  onChanged: (mode) => setState(() => _mode = mode),
                ),
                const SizedBox(height: 20),
                _ModeCard(
                  emoji: '⚡',
                  title: 'Rápida',
                  subtitle: 'Temática al azar',
                  color: AppColors.yellow,
                  onTap: _spin,
                ),
                const SizedBox(height: 14),
                _ModeCard(
                  emoji: '✏️',
                  title: 'Escribir temática',
                  subtitle: 'Ustedes eligen de qué',
                  color: Colors.white,
                  onTap: _playCustom,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          tileColor: Colors.white.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          secondary: const Icon(Icons.videocam, color: Colors.white),
          title: const Text(
            'Grabar video',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          value: settings.recordVideo,
          onChanged: (v) {
            ref
                .read(settingsProvider.notifier)
                .update(settings.copyWith(recordVideo: v));
            if (v && _camera == null) _openCamera();
          },
        ),
      ],
    );
  }

  Widget _bombView() {
    final game = _game!;
    final playing = _phase == _Phase.playing;
    final camera = _camera;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 44),
        // La temática, arriba.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            game.topic?.topic ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // La rueda de letras, con la bomba en el centro.
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                // Al explotar, las letras salen volando (BombExplosion).
                child: LetterWheel(
                  letters: _phase == _Phase.boom ? const [] : game.letters,
                  used: game.used,
                  enabled: playing,
                  pulse: _pulse,
                  seconds: _mode == LettersMode.turn && _phase == _Phase.playing
                      ? _secondsLeft
                      : null,
                  onTap: _choose,
                ),
              ),
              if (_passFlash)
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('¡Pasa el celular!', style: _title(24)),
                  ),
                ),
              // Quien tiene el celular se ve: así sabe que lo están grabando.
              if (camera != null &&
                  camera.value.isInitialized &&
                  _recording &&
                  playing)
                Positioned(
                  top: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 66,
                      height: 88,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(camera),
                          const Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(
                                Icons.fiber_manual_record,
                                color: Colors.red,
                                size: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Text(
          game.passes == 1 ? '1 pase' : '${game.passes} pases',
          textAlign: TextAlign.center,
          style: _title(22),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Se usaron todas las letras: "Ronda 1 finalizada" y "¡Seguir!". La
  /// bomba está detenida mientras tanto.
  Widget _roundOverView() {
    final game = _game!;
    final next = game.round + 1;
    return Column(
      children: [
        const Spacer(),
        const Text('🎉', style: TextStyle(fontSize: 80)),
        Text(
          'Ronda ${game.round} finalizada',
          textAlign: TextAlign.center,
          style: _title(44),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            'Ahora debes mencionar ${LettersGame.number(next)} palabras '
            'para pasar',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Las letras vuelven a quedar libres. La bomba está en pausa.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        _bigButton(
          '¡Seguir!',
          icon: Icons.play_arrow_rounded,
          color: AppColors.green,
          textColor: Colors.white,
          height: 80,
          onPressed: _nextRound,
        ),
      ],
    );
  }

  Widget _resultView() {
    final game = _game!;
    final bomb = game.bombs.last;
    final video = ref.watch(turnVideoProvider);
    return ListView(
      children: [
        const SizedBox(height: 40),
        Text(
          '¡BOOM!',
          textAlign: TextAlign.center,
          style: _title(64).copyWith(color: AppColors.yellow),
        ),
        Text(
          'Perdió quien tenía el celular',
          textAlign: TextAlign.center,
          style: _title(22),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.surfaces.card,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Text(
                bomb.topic.topic,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: context.surfaces.onCard,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${bomb.passes == 1 ? '1 pase' : '${bomb.passes} pases'} · '
                'ronda ${bomb.round} · ${bomb.fuse.inSeconds} s',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.surfaces.onCard,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _bigButton(
          'Girar la ruleta de castigos',
          icon: Icons.casino,
          color: AppColors.yellow,
          onPressed: () => context.push(Routes.punishmentSpin),
        ),
        if (video.status != TurnVideoStatus.none) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: VideoButton(video: video)),
              if (video.status == TurnVideoStatus.ready) ...[
                const SizedBox(width: 10),
                SaveVideoButton(
                  saved: video.saved,
                  saving: false,
                  auto: ref.watch(settingsProvider).autoSaveVideo,
                  onPressed: () async {
                    final message = await ref
                        .read(turnVideoProvider.notifier)
                        .save();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(message)));
                  },
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 12),
        _bigButton(
          'Otra bomba',
          icon: Icons.refresh,
          color: Colors.white,
          onPressed: _custom == null ? _spin : _playCustom,
        ),
        if (game.bombs.length > 1) ...[
          const SizedBox(height: 16),
          for (final b in game.bombs.reversed.skip(1))
            Text(
              b.summary,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ],
    );
  }

  static TextStyle _title(double size) => TextStyle(
    fontFamily: AppFonts.display,
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    height: 1.1,
  );

  Widget _bigButton(
    String label, {
    required IconData icon,
    required Color color,
    Color textColor = AppColors.ink,
    double height = 64,
    VoidCallback? onPressed,
  }) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        disabledBackgroundColor: color.withValues(alpha: 0.5),
        disabledForegroundColor: textColor.withValues(alpha: 0.7),
        minimumSize: Size.fromHeight(height),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: TextStyle(
          fontFamily: AppFonts.display,
          fontSize: height > 80 ? 40 : 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: height > 80 ? 40 : 26),
      label: Text(label),
    );
  }
}

/// Una de las dos formas de jugar en el inicio: una tarjeta grande con su
/// emoji, el nombre y una línea corta.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 6,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // El emoji en un círculo, para que se vea sobre cualquier
              // color (el rayo amarillo se perdía en la tarjeta amarilla).
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color == Colors.white
                      ? const Color(0xFFF1ECFA)
                      : Colors.white,
                  border: Border.all(
                    color: AppColors.ink.withValues(alpha: 0.12),
                    width: 2,
                  ),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 32)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        style: const TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 28,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.play_arrow_rounded,
                size: 36,
                color: AppColors.ink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La ventana para escribir la temática ("Cosas que hay en la playa").
/// Devuelve el texto, o null si se cierra.
class _TopicDialog extends StatefulWidget {
  const _TopicDialog({this.initial = ''});

  final String initial;

  @override
  State<_TopicDialog> createState() => _TopicDialogState();
}

class _TopicDialogState extends State<_TopicDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Escribir temática'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: LettersRules.maxTopicLength,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.go,
        onSubmitted: (_) => _play(),
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          hintText: 'Ej.: Cosas que hay en la playa',
        ),
      ),
      // El botón grande arriba y "Cancelar" debajo.
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        FilledButton(
          onPressed: _controller.text.trim().isEmpty ? null : _play,
          child: const Text('¡Jugar!'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: context.surfaces.accent),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

/// Cómo explota la bomba: "Mecha secreta" o "11 segundos", con una línea
/// que explica el elegido.
class _BombModePicker extends StatelessWidget {
  const _BombModePicker({required this.mode, required this.onChanged});

  final LettersMode mode;
  final ValueChanged<LettersMode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(LettersMode value, String emoji, String label) {
      final selected = mode == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$emoji $label',
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.ink : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              option(LettersMode.secret, '💣', 'Mecha secreta'),
              option(LettersMode.turn, '⏱️', '11 segundos'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          mode == LettersMode.secret
              ? 'Explota cuando nadie lo espera'
              : 'Cada quien tiene 11 segundos para responder',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
