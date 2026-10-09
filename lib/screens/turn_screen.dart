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
import '../widgets/word_card.dart';

enum _Phase { ready, countdown, playing, saving }

/// Un turno: preparación, cuenta regresiva, juego con el celular en la
/// frente y grabación con la cámara frontal.
class TurnScreen extends ConsumerStatefulWidget {
  const TurnScreen({super.key});

  @override
  ConsumerState<TurnScreen> createState() => _TurnScreenState();
}

class _TurnScreenState extends ConsumerState<TurnScreen> {
  static const _countdownFrom = 3;
  static const _feedbackDuration = Duration(milliseconds: 700);

  final _camera = CameraService();
  bool _cameraLoading = true;
  String? _cameraError;

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

  @override
  void initState() {
    super.initState();
    final game = ref.read(gameControllerProvider);
    _deck = [...game.currentDeck];
    _remaining = game.config.turnDuration;
    WakelockPlus.enable();
    _initCamera(game.config.resolution);
  }

  Future<void> _initCamera(VideoResolution resolution) async {
    try {
      await _camera.initialize(resolution);
    } on Exception catch (e) {
      _cameraError = e is CameraException && e.code.contains('Access')
          ? 'Sin permiso de cámara: el turno se jugará sin video.'
          : 'No se pudo abrir la cámara: el turno se jugará sin video.';
    }
    if (mounted) setState(() => _cameraLoading = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tilt?.cancel();
    _camera.dispose();
    WakelockPlus.disable();
    ScreenOrientation.portrait();
    super.dispose();
  }

  Future<void> _startCountdown() async {
    setState(() => _phase = _Phase.countdown);
    // La cuenta regresiva da tiempo de girar el celular y ponerlo en la
    // frente. También se empieza a grabar aquí, para absorber la demora de
    // la cámara al arrancar.
    await ScreenOrientation.landscape();
    try {
      await _camera.startRecording(ScreenOrientation.game);
    } on CameraException {
      _cameraError = 'No se pudo grabar este turno.';
    }
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
    _tilt = ref
        .read(tiltServiceProvider)
        .actions()
        .listen(
          (action) => _mark(
            action == TiltAction.hit ? WordOutcome.hit : WordOutcome.pass,
          ),
        );
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
    setState(() => _feedback = outcome);
    Future.delayed(_feedbackDuration, () {
      if (!mounted || _phase != _Phase.playing) return;
      if (_wordIndex + 1 >= _deck.length) {
        _endTurn();
      } else {
        setState(() {
          _feedback = null;
          _wordIndex++;
        });
      }
    });
  }

  Future<void> _endTurn() async {
    if (_phase == _Phase.saving) return;
    _timer?.cancel();
    await _tilt?.cancel();
    setState(() => _phase = _Phase.saving);

    String? videoPath;
    try {
      final recorded = await _camera.stopRecording();
      if (recorded != null) {
        videoPath = await ref.read(videoServiceProvider).keep(recorded);
      }
    } on Exception {
      videoPath = null;
    }
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
            videoPath: videoPath,
          ),
        );
    if (mounted) context.go(Routes.turnResult);
  }

  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Abandonar la partida?'),
        content: const Text(
          'Se perderán los puntajes y el video de este turno.',
        ),
        actions: [
          TextButton(
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
    try {
      final recorded = await _camera.stopRecording();
      if (recorded != null) {
        await ref.read(videoServiceProvider).delete(recorded.path);
      }
    } on Exception {
      // El archivo queda en la carpeta temporal del sistema.
    }
    await ScreenOrientation.portrait();
    if (mounted) context.go(Routes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
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
            _Phase.playing => _playingView(context),
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
            Text('Ronda ${game.round} de ${game.config.rounds}', style: white),
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
                    : const Icon(
                        Icons.videocam_off,
                        size: 72,
                        color: Colors.white70,
                      ),
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('¡Listo!'),
              onPressed: _cameraLoading ? null : _startCountdown,
            ),
          ],
        ),
      ),
    );
  }

  Widget _playingView(BuildContext context) {
    final card = WordCard(
      word: _deck[_wordIndex],
      remaining: _remaining,
      feedback: _feedback,
      recording: _camera.isRecording,
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
