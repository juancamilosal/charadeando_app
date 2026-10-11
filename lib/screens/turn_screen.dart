import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/countdown_view.dart';
import '../widgets/play_background.dart';
import '../widgets/tv_connect.dart';
import '../widgets/tv_turn_view.dart';
import '../widgets/word_card.dart';

enum _Phase { ready, countdown, playing, paused, saving }

/// Un turno: preparación, cuenta regresiva, juego con el celular en la
/// frente y grabación con la cámara frontal. Si la app se va a segundo
/// plano, el turno se pausa y al volver sigue donde quedó.
///
/// En el Modo TV el celular se duplica en el televisor y lo tiene un juez
/// del grupo rival, que marca con botones. No se graba, y si el televisor
/// se desconecta el turno se pausa y sigue al volver a conectarlo.
class TurnScreen extends ConsumerStatefulWidget {
  const TurnScreen({super.key});

  @override
  ConsumerState<TurnScreen> createState() => _TurnScreenState();
}

class _TurnScreenState extends ConsumerState<TurnScreen>
    with WidgetsBindingObserver {
  static const _countdownFrom = 3;
  static const _feedbackDuration = Duration(milliseconds: 700);

  final _camera = CameraService();
  bool _cameraLoading = true;
  String? _cameraError;

  /// Verdadero si la app pasó a segundo plano (por ejemplo, para ir a los
  /// ajustes). El diálogo de permisos solo la deja inactiva un momento.
  bool _wentAway = false;

  late final List<Word> _deck;
  final List<TurnEntry> _entries = [];
  int _wordIndex = 0;

  _Phase _phase = _Phase.ready;
  int _countdown = _countdownFrom;
  late Duration _remaining;
  Timer? _timer;
  StreamSubscription<TiltAction>? _tilt;

  /// Resultado que se está mostrando antes de pasar a la siguiente palabra.
  WordOutcome? _feedback;

  /// Verdadero después de la primera pausa: la cuenta regresiva dice
  /// "¡Seguimos!" en el video.
  bool _resumed = false;

  /// Verdadero si el turno se pausó porque se desconectó el televisor.
  bool _tvLost = false;

  // Grabación: una parte de video por cada tramo sin pausas, y los textos
  // que se escriben encima, medidos en el tiempo total grabado.
  final List<String> _segments = [];
  final List<Caption> _captions = [];
  final _segmentClock = Stopwatch();
  Duration _recorded = Duration.zero;
  bool _recording = false;
  (String, CaptionStyle, Duration)? _openCaption;

  Duration get _now => _recorded + _segmentClock.elapsed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final game = ref.read(gameControllerProvider);
    _deck = [...game.currentDeck];
    _remaining = game.config.turnDuration;
    WakelockPlus.enable();
    _initCamera();
  }

  /// Falso si eligieron jugar sin grabar o en Modo TV: no se abre la
  /// cámara.
  bool get _records => ref.read(gameControllerProvider).config.records;

  bool get _tvMode => ref.read(gameControllerProvider).config.tvMode;

  /// Verdadero si es Modo TV y el televisor no está conectado: no se puede
  /// empezar ni seguir el turno.
  bool _watchTvMissing() =>
      _tvMode && !(ref.watch(tvConnectedProvider).value ?? false);

  /// Pausa el turno si se desconecta el televisor, y lo retoma con la
  /// cuenta regresiva al volver a conectarlo.
  void _onTvChanged(AsyncValue<bool>? previous, AsyncValue<bool> next) {
    if (!_tvMode) return;
    final was = previous?.value ?? false;
    final now = next.value ?? false;
    if (was && !now) {
      if (_phase == _Phase.countdown || _phase == _Phase.playing) {
        _tvLost = true;
        _pause();
      }
    } else if (!was && now && _phase == _Phase.paused && _tvLost) {
      _tvLost = false;
      _startCountdown();
    }
  }

  Future<void> _initCamera() async {
    if (!_records) {
      setState(() => _cameraLoading = false);
      return;
    }
    setState(() {
      _cameraLoading = true;
      _cameraError = null;
    });
    try {
      await _camera.initialize(
        ref.read(gameControllerProvider).config.resolution,
      );
    } on Exception catch (e) {
      _cameraError = e is CameraException && e.code.contains('Access')
          ? 'Sin permiso de cámara: el turno se jugará sin video.'
          : 'No se pudo abrir la cámara: el turno se jugará sin video.';
    }
    if (mounted) setState(() => _cameraLoading = false);
  }

  bool get _cameraReady => _camera.controller?.value.isInitialized ?? false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_phase == _Phase.countdown || _phase == _Phase.playing) {
          _pause();
        } else if (_phase == _Phase.ready &&
            state != AppLifecycleState.inactive) {
          // El sistema le quita la cámara a la app en segundo plano.
          _camera.dispose();
        }
        if (state != AppLifecycleState.inactive) _wentAway = true;
      case AppLifecycleState.resumed:
        final wentAway = _wentAway;
        _wentAway = false;
        final waiting = _phase == _Phase.ready || _phase == _Phase.paused;
        // Si la cámara falló (por ejemplo, se negó el permiso), solo se
        // vuelve a intentar al regresar de segundo plano. Cerrar el diálogo
        // de permisos también "regresa" a la app, y reintentar ahí abre el
        // diálogo otra vez o falla de nuevo, sin parar.
        final retry = _cameraError == null || wentAway;
        if (waiting && _records && !_cameraReady && !_cameraLoading && retry) {
          _initCamera();
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _tilt?.cancel();
    _camera.dispose();
    WakelockPlus.disable();
    ScreenOrientation.portrait();
    super.dispose();
  }

  // --- Video ---------------------------------------------------------------

  Future<void> _startSegment() async {
    if (!_cameraReady) return;
    try {
      await _camera.startRecording(ScreenOrientation.game);
      _segmentClock
        ..reset()
        ..start();
      _recording = true;
    } on CameraException {
      _cameraError = 'No se pudo grabar esta parte del turno.';
    }
  }

  Future<void> _stopSegment() async {
    if (!_recording) return;
    _recording = false;
    _segmentClock.stop();
    var saved = false;
    try {
      final recorded = await _camera.stopRecording();
      if (recorded != null) {
        _segments.add(await ref.read(videoServiceProvider).keep(recorded));
        _recorded += _segmentClock.elapsed;
        saved = true;
      }
    } on Exception {
      saved = false;
    }
    // Si se perdió esta parte, sus textos tampoco van en el video.
    if (!saved) _captions.removeWhere((c) => c.start >= _recorded);
    _segmentClock.reset();
  }

  void _showCaption(String text, CaptionStyle style) {
    _closeCaption();
    _openCaption = (text, style, _now);
  }

  void _closeCaption() {
    final open = _openCaption;
    if (open == null) return;
    _captions.add(Caption(open.$1, open.$2, open.$3, _now));
    _openCaption = null;
  }

  // --- Juego ---------------------------------------------------------------

  Future<void> _startCountdown() async {
    _tvLost = false;
    setState(() {
      _phase = _Phase.countdown;
      _countdown = _countdownFrom;
    });
    // La cuenta regresiva da tiempo de girar el celular y ponerlo en la
    // frente. También se empieza a grabar aquí, para absorber la demora de
    // la cámara al arrancar.
    await ScreenOrientation.landscape();
    await _startSegment();
    if (_phase != _Phase.countdown) return;
    final group = ref.read(gameControllerProvider).currentGroup.name;
    _showCaption(
      _resumed ? '¡Seguimos!' : '¡Turno de $group!',
      CaptionStyle.title,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _startPlaying();
      }
    });
  }

  void _startPlaying() {
    setState(() => _phase = _Phase.playing);
    // Si se pausó justo después de marcar una palabra, se pasa a la
    // siguiente; si no, se vuelve a mostrar la que estaba.
    if (_feedback != null) {
      _nextWord();
      if (_phase != _Phase.playing) return;
    } else {
      _showCaption(_deck[_wordIndex].text, CaptionStyle.word);
    }
    // En el Modo TV el juez marca con los botones.
    if (!_tvMode) {
      _tilt = ref
          .read(tiltServiceProvider)
          .actions()
          .listen(
            (action) => _mark(
              action == TiltAction.hit ? WordOutcome.hit : WordOutcome.pass,
            ),
          );
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _remaining - const Duration(seconds: 1);
      if (remaining <= Duration.zero) {
        _endTurn();
      } else {
        setState(() => _remaining = remaining);
      }
    });
  }

  void _mark(WordOutcome outcome) {
    if (_phase != _Phase.playing || _feedback != null) return;
    _entries.add(TurnEntry(_deck[_wordIndex], outcome));
    outcome == WordOutcome.hit
        ? HapticFeedback.heavyImpact()
        : HapticFeedback.lightImpact();
    _showCaption(
      outcome == WordOutcome.hit ? '¡Correcto!' : 'Paso',
      outcome == WordOutcome.hit ? CaptionStyle.hit : CaptionStyle.pass,
    );
    setState(() => _feedback = outcome);
    Future.delayed(_feedbackDuration, () {
      if (mounted && _phase == _Phase.playing) _nextWord();
    });
  }

  void _nextWord() {
    if (_wordIndex + 1 >= _deck.length) {
      _endTurn();
      return;
    }
    setState(() {
      _feedback = null;
      _wordIndex++;
    });
    _showCaption(_deck[_wordIndex].text, CaptionStyle.word);
  }

  /// Detiene el reloj, los sensores y la grabación. Lo que se lleva del
  /// turno se conserva para continuar después.
  Future<void> _pause() async {
    if (_phase != _Phase.countdown && _phase != _Phase.playing) return;
    _timer?.cancel();
    await _tilt?.cancel();
    _tilt = null;
    setState(() {
      _phase = _Phase.paused;
      _resumed = true;
    });
    _closeCaption();
    await _stopSegment();
    await _camera.dispose();
  }

  Future<void> _endTurn() async {
    if (_phase == _Phase.saving) return;
    _timer?.cancel();
    await _tilt?.cancel();
    setState(() => _phase = _Phase.saving);
    _closeCaption();
    await _stopSegment();
    await _camera.dispose();
    await ScreenOrientation.portrait();

    final game = ref.read(gameControllerProvider);
    ref
        .read(gameControllerProvider.notifier)
        .finishTurn(
          Turn(
            round: game.round,
            groupIndex: game.groupIndex,
            entries: List.unmodifiable(_entries),
          ),
        );
    // El video con las palabras se arma mientras se ven los resultados.
    ref
        .read(turnVideoProvider.notifier)
        .process(
          TurnRecording(
            segments: List.unmodifiable(_segments),
            captions: List.unmodifiable(_captions),
            duration: _recorded,
          ),
          game.config.resolution,
        );
    if (mounted) context.go(Routes.turnResult);
  }

  Future<void> _confirmExit() async {
    await _pause();
    if (!mounted) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Abandonar la partida?'),
        content: const Text(
          'Se perderán los puntajes y el video de este turno.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.purple),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir jugando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abandonar'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    _timer?.cancel();
    await _tilt?.cancel();
    await _stopSegment();
    await ref.read(videoServiceProvider).deleteAll();
    await ScreenOrientation.portrait();
    if (mounted) context.go(Routes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    ref.listen(tvConnectedProvider, _onTvChanged);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _phase != _Phase.saving) _confirmExit();
      },
      child: PlayBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: switch (_phase) {
            _Phase.ready => _readyView(context, game),
            _Phase.countdown => CountdownView(value: _countdown),
            _Phase.playing =>
              game.config.tvMode ? _tvView(game) : _playingView(context, game),
            _Phase.paused => _pausedView(context),
            _Phase.saving => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          },
        ),
      ),
    );
  }

  Widget _readyView(BuildContext context, GameState game) {
    final controller = _camera.controller;
    final tvMissing = _watchTvMissing();
    const white = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${game.config.roundLabel(game.round)} · '
              '${WordCard.wordsLeftLabel(_wordsLeft(game))} en total',
              style: white,
            ),
            Text(
              'Turno de ${game.currentGroup.name}',
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 34,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: _cameraLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : controller != null && controller.value.isInitialized
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CameraPreview(controller),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            game.config.tvMode ? Icons.tv : Icons.videocam_off,
                            size: 72,
                            color: Colors.white70,
                          ),
                          if (!_records)
                            Text(
                              game.config.tvMode
                                  ? 'Modo TV: sin video'
                                  : 'Jugando sin grabar',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            if (game.config.tvMode) ...[
              const Text(
                'El que adivina se pone de espaldas al televisor. Un juez '
                'del grupo rival toma este celular y marca "Pasar" o '
                '"¡Correcto!".',
                style: white,
              ),
              const SizedBox(height: 12),
              const TvConnect(light: true),
            ] else
              const Text(
                'Al tocar "¡Listo!", la pantalla gira. Pon el celular en tu '
                'frente con la pantalla hacia tu grupo.\n'
                'Inclínalo hacia abajo si aciertas y hacia arriba para pasar.',
                style: white,
              ),
            if (_cameraError != null) ...[
              const SizedBox(height: 8),
              Text(
                _cameraError!,
                style: white.copyWith(color: AppColors.yellow),
              ),
            ],
            if (tvMissing) ...[
              const SizedBox(height: 8),
              Text(
                'Conecten el televisor para empezar el turno.',
                style: white.copyWith(color: AppColors.yellow),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('¡Listo!'),
              onPressed: _cameraLoading || tvMissing ? null : _startCountdown,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pausedView(BuildContext context) {
    final tvMissing = _watchTvMissing();
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.pause_circle_filled,
                  size: 72,
                  color: AppColors.yellow,
                ),
                Text(
                  _tvLost ? 'Se desconectó el televisor' : 'Juego en pausa',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Quedan ${_remaining.inSeconds} segundos · '
                  '${_entries.length} palabras marcadas',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (tvMissing) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Vuelvan a conectarlo y el juego sigue donde quedó.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.yellow,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cast),
                    label: const Text('Conectar el televisor'),
                    onPressed: () => connectTv(context, ref),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                    _cameraLoading
                        ? 'Preparando cámara…'
                        : tvMissing
                        ? 'Esperando el televisor…'
                        : 'Continuar',
                  ),
                  onPressed: _cameraLoading || tvMissing
                      ? null
                      : _startCountdown,
                ),
                TextButton(
                  onPressed: _confirmExit,
                  child: const Text('Abandonar partida'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Palabras que faltan por adivinar en toda la partida: las de todos los
  /// mazos menos las que ya se marcaron en este turno.
  int _wordsLeft(GameState game) =>
      game.decks.fold(0, (sum, deck) => sum + deck.length) - _entries.length;

  /// Lo que se ve en el televisor, con los botones del juez.
  Widget _tvView(GameState game) {
    final scores = [...game.scores];
    scores[game.groupIndex] += Turn(
      round: game.round,
      groupIndex: game.groupIndex,
      entries: _entries,
    ).points(game.config.scoringMode);
    return TvTurnView(
      word: _deck[_wordIndex],
      remaining: _remaining,
      feedback: _feedback,
      groupName: game.currentGroup.name,
      roundLabel: game.config.roundLabel(game.round),
      groups: game.groups,
      scores: scores,
      groupIndex: game.groupIndex,
      wordsLeft: _wordsLeft(game),
      onPass: () => _mark(WordOutcome.pass),
      onHit: () => _mark(WordOutcome.hit),
    );
  }

  Widget _playingView(BuildContext context, GameState game) {
    final card = WordCard(
      word: _deck[_wordIndex],
      remaining: _remaining,
      feedback: _feedback,
      recording: _camera.isRecording,
      wordsLeft: _wordsLeft(game),
    );
    if (!kDebugMode) return card;
    // En desarrollo, tocar la mitad izquierda pasa y la derecha acierta,
    // para probar sin inclinar el celular.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final width = MediaQuery.sizeOf(context).width;
        _mark(
          details.localPosition.dx < width / 2
              ? WordOutcome.pass
              : WordOutcome.hit,
        );
      },
      child: card,
    );
  }
}
