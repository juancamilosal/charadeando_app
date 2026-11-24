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
import '../widgets/play_background.dart';
import '../widgets/result_parts.dart';
import '../widgets/system_back.dart';

enum _Phase { loading, error, ready, spinning, playing, boom, result }

/// El juego "La Bomba" (por dentro, Letras). Sale una temática y una letra; quien tiene
/// el celular dice una palabra de la temática que empiece con la letra,
/// toca "¡Pasa!" y se lo pasa al siguiente. La bomba explota en un tiempo
/// secreto (de 20 a 60 segundos): pierde quien la tenía. Todo en vertical,
/// y si "Grabar video" está encendido, graba con la cámara de frente a
/// quien tiene el celular, con la temática y la letra encima.
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

  /// La letra que se ve mientras gira la ruleta.
  String _shownLetter = '?';
  Timer? _spinTimer;

  /// Tiempo de la bomba actual.
  final _clock = Stopwatch();
  Timer? _tickTimer;
  Timer? _fuseTimer;

  /// "¡Pasa el celular!" se ve un momento después de cada pase.
  bool _passFlash = false;
  Timer? _flashTimer;

  /// Medio segundo después de un pase no cuenta otro.
  Timer? _passCooldown;

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

  // --- La ruleta de letras ---------------------------------------------

  /// Saca la temática y gira la ruleta hasta la letra.
  void _spin() {
    final game = _game;
    if (game == null) return;
    ref.read(turnVideoProvider.notifier).discard().ignore();
    game.nextBomb();
    final letters = game.topic!.letters;
    setState(() => _phase = _Phase.spinning);
    var step = 0;
    const steps = 16;
    void turn() {
      if (!mounted || _phase != _Phase.spinning) return;
      step++;
      final last = step >= steps;
      setState(
        () => _shownLetter = last
            ? game.letter!
            : letters.length == 1
            ? letters.first
            : LettersRules.letters[_random.nextInt(
                LettersRules.letters.length,
              )],
      );
      ref.read(soundServiceProvider).play(SoundEffect.spin);
      if (last) {
        ref.read(hapticsProvider).heavy();
        _spinTimer = Timer(const Duration(milliseconds: 700), _start);
        return;
      }
      // Cada vez más despacio, como una ruleta que frena.
      _spinTimer = Timer(Duration(milliseconds: 60 + step * step * 2), turn);
    }

    turn();
  }

  // --- La bomba ------------------------------------------------------------

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
    _fuseTimer = Timer(game.fuse, _explode);
    _tick();
    if (mounted) setState(() {});
  }

  /// El tic-tac, cada vez más rápido.
  void _tick() {
    final game = _game;
    if (!mounted || _phase != _Phase.playing || game == null) return;
    ref.read(soundServiceProvider).play(SoundEffect.tick);
    _tickTimer = Timer(
      LettersRules.tickInterval(_clock.elapsed, game.fuse),
      _tick,
    );
    setState(() {});
  }

  void _pass() {
    if (_phase != _Phase.playing) return;
    // Un toque cada medio segundo como mucho: si no, dos toques seguidos
    // contarían dos pases.
    if (_passCooldown?.isActive ?? false) return;
    _passCooldown = Timer(const Duration(milliseconds: 500), () {});
    _game!.pass();
    ref.read(hapticsProvider).heavy();
    ref.read(soundServiceProvider).play(SoundEffect.hit);
    _flashTimer?.cancel();
    setState(() => _passFlash = true);
    _flashTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _passFlash = false);
    });
  }

  Future<void> _explode() async {
    if (!mounted || _phase != _Phase.playing) return;
    _tickTimer?.cancel();
    _clock.stop();
    final game = _game!;
    final bomb = game.explode();
    setState(() => _phase = _Phase.boom);
    ref.read(soundServiceProvider).play(SoundEffect.boom);
    final haptics = ref.read(hapticsProvider);
    for (var i = 0; i < 4; i++) {
      Timer(Duration(milliseconds: i * 180), haptics.heavy);
    }
    ref.read(lettersBankProvider).remember(bomb.topic).ignore();
    // El video sigue un momento después del BOOM, para ver las caras.
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    final recorded = _clock.elapsed + const Duration(milliseconds: 2400);
    await _finishVideo(bomb, recorded);
    if (mounted && _phase == _Phase.boom) {
      setState(() => _phase = _Phase.result);
    }
  }

  Future<void> _finishVideo(LettersBomb bomb, Duration recorded) async {
    final camera = _camera;
    if (!_recording || camera == null) return;
    _recording = false;
    try {
      final file = await camera.stopVideoRecording();
      final subtitles = VideoRenderer.lettersSubtitles(
        topic: bomb.topic.topic,
        letter: bomb.letter,
        playing: bomb.fuse,
        boomAt: bomb.fuse,
        end: recorded,
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
              category: 'La Bomba: ${bomb.topic.topic} · La ${bomb.letter}',
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
    _spinTimer?.cancel();
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
    if (_phase == _Phase.playing || _phase == _Phase.spinning) {
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
    _spinTimer?.cancel();
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
                    _Phase.spinning ||
                    _Phase.playing ||
                    _Phase.boom => _bombView(),
                    _Phase.result => _resultView(),
                  },
                ),
              ),
              if (_phase == _Phase.boom)
                const Positioned.fill(child: BombExplosion()),
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
        ],
      ),
    );
  }

  Widget _readyView() {
    final settings = ref.watch(settingsProvider);
    return Column(
      children: [
        // Si no cabe (celulares pequeños), se desplaza; el interruptor y
        // el botón quedan siempre abajo.
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text('💣', style: TextStyle(fontSize: 96)),
                Text(
                  'La Bomba',
                  textAlign: TextAlign.center,
                  style: _title(52),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sale una temática y una letra. Di una palabra de la '
                  'temática que empiece con esa letra, toca "¡Pasa!" y '
                  'pásale el celular al siguiente.\n\nLa bomba explota '
                  'cuando nadie lo espera: ¡que no te explote a ti!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
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
        const SizedBox(height: 16),
        _bigButton(
          '¡Girar!',
          icon: Icons.casino,
          color: AppColors.yellow,
          onPressed: _spin,
        ),
      ],
    );
  }

  Widget _bombView() {
    final game = _game!;
    final playing = _phase == _Phase.playing || _phase == _Phase.boom;
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
        // La letra, en el centro.
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedScale(
                scale: _passFlash ? 1.08 : 1,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 250,
                  height: 250,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 6),
                  ),
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _shownLetter,
                        style: const TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 190,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Color(0x55000000),
                              offset: Offset(0, 6),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_passFlash)
                Positioned(
                  bottom: 8,
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
                  top: 12,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 78,
                      height: 104,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(camera),
                          const Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.fiber_manual_record,
                                color: Colors.red,
                                size: 14,
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
          _phase == _Phase.spinning
              ? 'Girando…'
              : game.passes == 1
              ? '1 pase'
              : '${game.passes} pases',
          textAlign: TextAlign.center,
          style: _title(22),
        ),
        const SizedBox(height: 12),
        _bigButton(
          '¡Pasa!',
          icon: Icons.east,
          color: AppColors.green,
          textColor: Colors.white,
          height: 110,
          onPressed: _phase == _Phase.playing ? _pass : null,
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
                'La ${bomb.letter} · '
                '${bomb.passes == 1 ? '1 pase' : '${bomb.passes} pases'} · '
                '${bomb.fuse.inSeconds} s',
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
          onPressed: _spin,
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
