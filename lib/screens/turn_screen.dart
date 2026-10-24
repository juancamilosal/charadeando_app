import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/countdown_view.dart';
import '../widgets/end_game_dialog.dart';
import '../widgets/judge_setup.dart' show judgeStatus;
import '../widgets/play_background.dart';
import '../widgets/tv_connect.dart';
import '../widgets/tv_turn_view.dart';
import '../widgets/word_card.dart';

enum _Phase { ready, placing, countdown, playing, paused, saving }

/// Un turno: preparación, "Ponte el celular en la frente" (solo si se marca
/// inclinando), cuenta regresiva, juego con el celular en la frente y
/// grabación con la cámara frontal. Si la app se va a segundo
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
  static const _clockFrom = Duration(seconds: 10);
  static const _feedbackDuration = Duration(milliseconds: 500);

  /// "Ponte el celular en la frente": cuándo aparece "Empezar igual" y
  /// cuándo arranca sola la cuenta si el sensor no lo reconoce.
  static const _startAnywayAfter = Duration(seconds: 8);
  static const _autoStartAfter = Duration(seconds: 15);

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

  /// Mientras se espera que el jugador se ponga el celular en la frente.
  StreamSubscription<void>? _placement;
  Timer? _placementHelp;

  /// Verdadero cuando ya pasó un rato sin reconocer el celular en la
  /// frente: aparece "Empezar igual".
  bool _showStartAnyway = false;

  /// Resultado que se está mostrando antes de pasar a la siguiente palabra.
  WordOutcome? _feedback;

  /// Verdadero después de la primera pausa: la cuenta regresiva dice
  /// "¡Seguimos!" en el video.
  bool _resumed = false;

  /// Verdadero si el turno se pausó porque se desconectó el televisor.
  bool _tvLost = false;

  /// Celular juez: la sala, si se juega con él. Lo que marca el juez cuenta
  /// igual que inclinar el celular; mientras hay un juez conectado, la
  /// inclinación (y el toque) no marcan.
  JudgeRoom? _judge;
  StreamSubscription<WordOutcome>? _judgeActions;
  int _judges = 0;

  bool get _judgeConnected => _judges > 0;

  // Grabación: una parte de video por cada tramo sin pausas, y los textos
  // que se escriben encima, medidos en el tiempo total grabado.
  final List<String> _segments = [];
  final List<Caption> _captions = [];
  final _segmentClock = Stopwatch();
  Duration _recorded = Duration.zero;
  bool _recording = false;
  (String, CaptionStyle, Duration, String?)? _openCaption;

  Duration get _now => _recorded + _segmentClock.elapsed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final game = ref.read(gameControllerProvider);
    _deck = [...game.currentDeck];
    _remaining = game.config.turnDuration;
    final judge = game.config.judgePhone
        ? ref.read(judgeProvider.notifier).room
        : null;
    _judge = judge;
    if (judge != null) {
      _judges = judge.judges.value;
      judge.judges.addListener(_onJudgesChanged);
      _judgeActions = judge.actions.listen((outcome) {
        if (_phase == _Phase.playing) _mark(outcome);
      });
      _syncJudge();
    }
    WakelockPlus.enable();
    // Fotomímica: las dos primeras fotos se dejan listas para mostrar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precachePhoto(0);
      _precachePhoto(1);
    });
    // La pantalla de antes del turno ya va en horizontal, con la cámara.
    ScreenOrientation.landscape();
    _initCamera();
  }

  /// Falso si eligieron jugar sin grabar o en Modo TV: no se abre la
  /// cámara.
  bool get _records => ref.read(gameControllerProvider).config.records;

  bool get _tvMode => ref.read(gameControllerProvider).config.tvMode;

  /// Ajuste "Controlador: Toque": la mitad derecha de la pantalla es
  /// acierto y la izquierda, pasar.
  bool get _touch =>
      ref.read(settingsProvider).controller == PlayController.touch;

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
    } on Exception catch (e, stack) {
      final denied = e is CameraException && e.code.contains('Access');
      // Negar el permiso es decisión del jugador, no un error.
      if (!denied) {
        ErrorReporter.instance.report(e, stack, reason: 'Abrir la cámara');
      }
      _cameraError = denied
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
        if (_phase == _Phase.placing) {
          // Bajar la barra de notificaciones deja la app inactiva un
          // momento: eso no interrumpe la espera.
          if (state != AppLifecycleState.inactive) _stopPlacing();
        } else if (_phase == _Phase.countdown || _phase == _Phase.playing) {
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

  /// Cambió cuántos jueces hay. Si el juez se va en pleno turno, se avisa
  /// y la inclinación vuelve a marcar.
  void _onJudgesChanged() {
    final was = _judges;
    final now = _judge?.judges.value ?? 0;
    if (!mounted || was == now) return;
    setState(() => _judges = now);
    // Si el juez entra mientras se espera el celular en la frente, ya no
    // hace falta: marca él.
    if (_phase == _Phase.placing && now > 0) {
      _placed();
      return;
    }
    final inTurn = _phase == _Phase.playing || _phase == _Phase.countdown;
    if (!inTurn) return;
    final text = was > 0 && now == 0
        ? (_touch
              ? 'Se desconectó el celular juez: marquen tocando la pantalla.'
              : 'Se desconectó el celular juez: marquen inclinando el '
                    'celular.')
        : was == 0 && now > 0
        ? 'Juez conectado ✓'
        : null;
    if (text == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
      );
  }

  /// Le cuenta al juez cómo va el turno: la palabra, el tiempo, el equipo y
  /// sus puntos. Solo manda si algo cambió.
  void _syncJudge() {
    final judge = _judge;
    if (judge == null || _phase == _Phase.saving) return;
    final game = ref.read(gameControllerProvider);
    final config = game.config;
    final playing = _phase == _Phase.playing && _wordIndex < _deck.length;
    final word = playing ? _deck[_wordIndex] : null;
    final turn = Turn(
      round: game.round,
      groupIndex: game.groupIndex,
      entries: _entries,
    );
    judge.send(
      JudgeState(
        phase: playing ? JudgeState.playing : JudgeState.waiting,
        word: word?.text,
        category: word == null
            ? config.categoryLabel
            : config.wordCategoryLabel(word) ?? config.categoryLabel,
        seconds: _remaining.inSeconds,
        team: game.inGroups ? game.currentGroup.name : null,
        // Sin equipos, solo los puntos de este turno.
        points:
            (game.inGroups ? game.scores[game.groupIndex] : 0) +
            turn.points(config.scoringMode),
        // Mientras se ve "¡Correcto!" o "Paso", el juez también lo ve: así
        // sabe que la marca llegó.
        mark: playing ? _feedback : null,
        // Y la cuenta regresiva antes de empezar.
        countdown: _phase == _Phase.countdown ? _countdown : null,
      ),
    );
  }

  /// Al terminar el turno (o la partida), el juez ve el resumen con las
  /// palabras. Si sigue la pantalla de resultados del turno, todavía las
  /// puede corregir.
  void _judgeTurnOver({required bool gameOver, bool editable = true}) {
    final judge = _judge;
    if (judge == null) return;
    judge.send(
      judgeTurnSummary(
        ref.read(gameControllerProvider),
        gameOver: gameOver,
        editable: editable,
      ),
    );
  }

  // Cada cambio en pantalla (el tiempo, la palabra, el resultado) también le
  // llega al juez.
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _syncJudge();
  }

  @override
  void dispose() {
    _judge?.judges.removeListener(_onJudgesChanged);
    _judgeActions?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _tilt?.cancel();
    _cancelPlacing();
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
      ErrorReporter.instance.setKey(CrashKeys.recording, true);
    } on CameraException catch (e, stack) {
      ErrorReporter.instance.report(e, stack, reason: 'Empezar a grabar');
      _cameraError = 'No se pudo grabar esta parte del turno.';
    }
  }

  Future<void> _stopSegment() async {
    if (!_recording) return;
    _recording = false;
    ErrorReporter.instance.setKey(CrashKeys.recording, false);
    _segmentClock.stop();
    var saved = false;
    try {
      final recorded = await _camera.stopRecording();
      if (recorded != null) {
        _segments.add(await ref.read(videoServiceProvider).keep(recorded));
        _recorded += _segmentClock.elapsed;
        saved = true;
      }
    } on Exception catch (e, stack) {
      ErrorReporter.instance.report(e, stack, reason: 'Guardar la grabación');
      saved = false;
    }
    // Si se perdió esta parte, sus textos tampoco van en el video.
    if (!saved) _captions.removeWhere((c) => c.start >= _recorded);
    _segmentClock.reset();
  }

  void _showCaption(String text, CaptionStyle style, {String? label}) {
    _closeCaption();
    _openCaption = (text, style, _now, label);
  }

  /// La palabra que se está adivinando, con su categoría en una mezcla.
  void _showWordCaption() {
    final word = _deck[_wordIndex];
    _showCaption(
      word.text,
      CaptionStyle.word,
      label: _config.wordCategoryLabel(word),
    );
  }

  GameConfig get _config => ref.read(gameControllerProvider).config;

  void _closeCaption() {
    final open = _openCaption;
    if (open == null) return;
    _captions.add(Caption(open.$1, open.$2, open.$3, _now, label: open.$4));
    _openCaption = null;
  }

  // --- Juego ---------------------------------------------------------------

  /// Verdadero si se marca inclinando el celular: antes de la cuenta se
  /// espera a que el jugador lo tenga en la frente, para que la inclinación
  /// se calibre con el celular ya puesto. Con Toque, en Modo TV o con el
  /// juez conectado nadie lo tiene en la frente.
  bool get _waitsForForehead => !_tvMode && !_touch && !_judgeConnected;

  /// "¡Listo!" o "Continuar": primero "Ponte el celular en la frente" y,
  /// cuando está puesto y quieto, la cuenta regresiva.
  void _begin() {
    if (!_waitsForForehead) {
      _startCountdown();
      return;
    }
    setState(() {
      _phase = _Phase.placing;
      _showStartAnyway = false;
    });
    ScreenOrientation.landscape();
    _placement = ref
        .read(tiltServiceProvider)
        .onForehead()
        .listen(
          (_) => _placed(),
          // Sin acelerómetro no hay nada que esperar.
          onError: (Object _) => _placed(),
        );
    // Si el sensor no lo reconoce, que nadie se quede esperando: pasado
    // un rato para acomodarse sale "Empezar igual" y, si nadie lo toca, la
    // cuenta arranca sola (con el celular en la frente no se ve el botón).
    _placementHelp = Timer(_startAnywayAfter, () {
      if (!mounted || _phase != _Phase.placing) return;
      setState(() => _showStartAnyway = true);
      _placementHelp = Timer(_autoStartAfter - _startAnywayAfter, _placed);
    });
  }

  /// El celular ya está en la frente (o tocaron "Empezar igual").
  void _placed() {
    if (_phase != _Phase.placing) return;
    _cancelPlacing();
    ref.read(hapticsProvider).light();
    _startCountdown();
  }

  void _cancelPlacing() {
    _placement?.cancel();
    _placement = null;
    _placementHelp?.cancel();
    _placementHelp = null;
  }

  /// La app se fue a segundo plano mientras se esperaba el celular en la
  /// frente: se vuelve a la pantalla de antes (sin cámara, que el sistema
  /// le quita a la app).
  void _stopPlacing() {
    _cancelPlacing();
    setState(() => _phase = _resumed ? _Phase.paused : _Phase.ready);
    _camera.dispose();
  }

  Future<void> _startCountdown() async {
    _cancelPlacing();
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
    final game = ref.read(gameControllerProvider);
    _showCaption(
      _resumed
          ? '¡Seguimos!'
          : game.inGroups
          ? '¡Turno de ${game.currentGroup.name}!'
          : '¡A jugar!',
      CaptionStyle.title,
    );
    // Un pitido en cada número y uno más agudo al arrancar.
    final sounds = ref.read(soundServiceProvider);
    sounds.play(SoundEffect.countdown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
        sounds.play(SoundEffect.countdown);
      } else {
        timer.cancel();
        sounds.play(SoundEffect.start);
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
      _showWordCaption();
    }
    // En el Modo TV el juez marca con los botones, y con el controlador
    // Toque se marca tocando la pantalla.
    if (!_tvMode && !_touch) {
      _tilt = ref.read(tiltServiceProvider).actions().listen((action) {
        // Con el juez conectado, inclinar no marca.
        if (_judgeConnected) return;
        _mark(action == TiltAction.hit ? WordOutcome.hit : WordOutcome.pass);
      });
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _remaining - const Duration(seconds: 1);
      if (remaining <= Duration.zero) {
        _endTurn();
      } else {
        setState(() => _remaining = remaining);
        // En los últimos segundos se oye el reloj, un segundo a la vez.
        if (remaining <= _clockFrom) {
          ref.read(soundServiceProvider).play(SoundEffect.clock);
        }
      }
    });
  }

  void _mark(WordOutcome outcome) {
    if (_phase != _Phase.playing || _feedback != null) return;
    _entries.add(TurnEntry(_deck[_wordIndex], outcome));
    // Mientras se ve "¡Correcto!" o "Paso", se prepara la foto siguiente.
    _precachePhoto(_wordIndex + 2);
    final haptics = ref.read(hapticsProvider);
    outcome == WordOutcome.hit ? haptics.heavy() : haptics.light();
    ref
        .read(soundServiceProvider)
        .play(outcome == WordOutcome.hit ? SoundEffect.hit : SoundEffect.pass);
    _showCaption(
      outcome == WordOutcome.hit ? '¡Correcto!' : 'Paso',
      outcome == WordOutcome.hit ? CaptionStyle.hit : CaptionStyle.pass,
    );
    setState(() => _feedback = outcome);
    Future.delayed(_feedbackDuration, () {
      if (mounted && _phase == _Phase.playing) _nextWord();
    });
  }

  /// En Fotomímica, deja la foto del objeto [index] lista en memoria para
  /// que se vea al instante. La foto ya está en el celular.
  void _precachePhoto(int index) {
    if (!mounted || index >= _deck.length) return;
    final image = _deck[index].image;
    if (image == null) return;
    // Si falla, la foto se carga al mostrarla (o se ve su nombre).
    precacheImage(FileImage(File(image)), context, onError: (_, _) {}).ignore();
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
    _showWordCaption();
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
    // Una marimba suave cierra el turno, y la música de la app vuelve
    // cuando termina, no encima de ella.
    if (ref.read(soundServiceProvider).play(SoundEffect.timeUp)) {
      ref.read(backgroundMusicProvider).holdFor(AssetEffectPlayer.timeUpLength);
    }
    await _tilt?.cancel();
    setState(() => _phase = _Phase.saving);
    _closeCaption();
    await _stopSegment();
    await _camera.dispose();
    await ScreenOrientation.portrait();

    final game = ref.read(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    controller.finishTurn(
      Turn(
        round: game.round,
        groupIndex: game.groupIndex,
        entries: List.unmodifiable(_entries),
      ),
    );
    _judgeTurnOver(gameOver: controller.afterAdvance.finished);
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
    // Se abandona después de al menos un turno: cuenta como no terminada.
    ref.read(gameControllerProvider.notifier).recordStats();
    if (mounted) context.go(Routes.categories);
  }

  /// "Finalizar juego": termina la partida y muestra los puntajes. Si el
  /// turno estaba en pausa, las palabras que ya se marcaron cuentan.
  Future<void> _endGame() async {
    await _pause();
    if (!mounted) return;
    final game = ref.read(gameControllerProvider);
    final played = game.turns.isNotEmpty || _entries.isNotEmpty;
    if (!await confirmEndGame(context, played: played) || !mounted) return;
    _timer?.cancel();
    await _tilt?.cancel();
    _tilt = null;
    setState(() => _phase = _Phase.saving);
    await _stopSegment();
    await _camera.dispose();
    try {
      await ref.read(videoServiceProvider).deleteAll();
    } on Exception catch (e) {
      // La pantalla final vuelve a intentar borrar los videos temporales.
      debugPrint('[Turno] No se pudieron borrar los videos: $e');
    }
    await ScreenOrientation.portrait();
    final controller = ref.read(gameControllerProvider.notifier);
    if (_entries.isNotEmpty) {
      controller.finishTurn(
        Turn(
          round: game.round,
          groupIndex: game.groupIndex,
          entries: List.unmodifiable(_entries),
        ),
      );
    }
    controller.endGame();
    // La partida rápida no tiene resultado final: muestra el del turno.
    final quick = game.config.quick;
    // Si sigue la pantalla de resultados del turno (partida rápida), allí
    // todavía se corrige; si no, el resumen queda fijo.
    _judgeTurnOver(gameOver: true, editable: quick && _entries.isNotEmpty);
    if (!mounted) return;
    context.go(
      !played || (quick && _entries.isEmpty)
          ? Routes.categories
          : quick
          ? Routes.turnResult
          : Routes.finalResult,
    );
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
            _Phase.placing => _placingView(),
            _Phase.countdown => CountdownView(value: _countdown),
            _Phase.playing =>
              game.config.tvMode ? _tvView(game) : _playingView(context, game),
            _Phase.paused => _pausedView(context),
            _Phase.saving => Center(
              child: CircularProgressIndicator(color: context.onBackdrop),
            ),
          },
        ),
      ),
    );
  }

  /// "Ponte el celular en la frente para comenzar": la cuenta empieza sola
  /// cuando el celular está en la frente y quieto.
  Widget _placingView() {
    return PlayBackground(
      colors: AppColors.countdown,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.face_retouching_natural,
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ponte el celular en la frente para comenzar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 34,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Con la pantalla hacia tus amigos. Cuando esté quieto, '
                  'empieza la cuenta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (_showStartAnyway) ...[
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Empezar igual'),
                    onPressed: _placed,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Antes del turno, en horizontal: de fondo la cámara frontal en vivo
  /// (todavía sin grabar) y a la izquierda el grupo, cómo se juega y
  /// "¡Listo!". Sin video o en Modo TV, sobre el fondo de la app.
  Widget _readyView(BuildContext context, GameState game) {
    final controller = _camera.controller;
    final tvMissing = _watchTvMissing();
    final config = game.config;
    final camera =
        !_cameraLoading && controller != null && controller.value.isInitialized
        ? controller
        : null;
    // Sobre la cámara, con el degradado oscuro, los textos van en blanco.
    final on = camera != null ? Colors.white : context.onBackdrop;
    final small = TextStyle(
      color: on,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Solo con grupos se dice a quién le toca.
        if (game.inGroups && !config.quick) ...[
          Text(
            game.turnTitle,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: on,
            ),
          ),
          const SizedBox(height: 10),
        ],
        // Con el juez conectado, él marca: no hace falta inclinar.
        if (_judgeConnected)
          Text(
            '${judgeStatus(_judges)} · El juez marca desde su celular.',
            textAlign: TextAlign.center,
            style: small,
          )
        else ...[
          _HowToHint(tv: config.tvMode, touch: _touch),
          if (_judge != null) ...[
            const SizedBox(height: 6),
            Text(
              'Celular juez: ${judgeStatus(0)}',
              textAlign: TextAlign.center,
              style: small,
            ),
          ],
        ],
        // Sin televisor no se puede empezar: se ve cómo conectarlo.
        if (tvMissing) ...[
          const SizedBox(height: 8),
          const TvConnect(light: true),
        ],
        if (_cameraError != null) ...[
          const SizedBox(height: 6),
          Text(_cameraError!, style: small.copyWith(color: AppColors.yellow)),
        ],
        if (tvMissing) ...[
          const SizedBox(height: 6),
          Text(
            'Conecten el televisor para empezar el turno.',
            style: small.copyWith(color: AppColors.yellow),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('¡Listo!'),
          onPressed: _cameraLoading || tvMissing ? null : _begin,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth > box.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (camera != null) ...[
              _CameraBackground(controller: camera),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xCC12052B),
                      Color(0x6612052B),
                      Color(0x0012052B),
                    ],
                    stops: [0, 0.45, 0.75],
                  ),
                ),
              ),
            ],
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Stack(
                  children: [
                    if (camera != null)
                      const Align(
                        alignment: Alignment.topRight,
                        child: _CameraTag(),
                      ),
                    Align(
                      alignment: wide
                          ? Alignment.centerLeft
                          : Alignment.bottomLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: wide ? box.maxWidth * 0.5 : 420,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextButtonTheme(
                                data: TextButtonThemeData(
                                  style: TextButton.styleFrom(
                                    foregroundColor: on,
                                  ),
                                ),
                                child: Wrap(
                                  children: [
                                    EndGameButton(
                                      onPressed: _endGame,
                                      compact: true,
                                    ),
                                    // Con el TV conectado, desconectarlo es
                                    // un botón pequeño, junto a "Finalizar".
                                    if (config.tvMode && !tvMissing)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.cancel_presentation,
                                        ),
                                        color: on,
                                        tooltip: 'Desconectar TV',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () =>
                                            disconnectTv(context, ref),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              content,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
                  onPressed: _cameraLoading || tvMissing ? null : _begin,
                ),
                EndGameButton(onPressed: _endGame),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Palabras que faltan de toda la partida, con las escritas por los
  /// grupos. Con palabras automáticas no se muestra: el turno dura hasta
  /// que se acabe el tiempo.
  int? _wordsLeft(GameState game) {
    if (game.config.untilTimeRunsOut) return null;
    return game.decks.fold<int>(0, (sum, deck) => sum + deck.length) -
        _entries.length;
  }

  /// "Ronda 1 de 3 · hasta que se acabe el tiempo", según las palabras.
  /// Lo que se ve en el televisor, con los botones del juez.
  Widget _tvView(GameState game) {
    return TvTurnView(
      word: _deck[_wordIndex],
      remaining: _remaining,
      feedback: _feedback,
      title: game.turnTitle,
      onPass: () => _mark(WordOutcome.pass),
      onHit: () => _mark(WordOutcome.hit),
      onEndGame: _endGame,
    );
  }

  Widget _playingView(BuildContext context, GameState game) {
    final touch = _touch;
    final card = WordCard(
      // Con Toque, la palabra no llega a las marcas de los bordes.
      sideMargin: touch ? _TouchMark.width + 24 : 32,
      word: _deck[_wordIndex],
      remaining: _remaining,
      feedback: _feedback,
      recording: _camera.isRecording,
      wordsLeft: _wordsLeft(game),
      onEndGame: _endGame,
    );
    // En desarrollo también se puede tocar, para probar sin inclinar.
    if (!touch && !kDebugMode) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        // Con el juez conectado, tocar no marca.
        if (_judgeConnected) return;
        final width = MediaQuery.sizeOf(context).width;
        _mark(
          details.localPosition.dx < width / 2
              ? WordOutcome.pass
              : WordOutcome.hit,
        );
      },
      child: touch
          ? Stack(
              fit: StackFit.expand,
              children: [
                card,
                const _TouchMark(left: true),
                const _TouchMark(left: false),
              ],
            )
          : card,
    );
  }
}

/// Antes del turno, cómo se juega con dos píldoras, según el controlador:
/// abajo si aciertas y arriba para pasar, o tocar a la derecha o a la
/// izquierda. En el Modo TV, "Correcto" y "Pasar" (los botones del juez).
class _HowToHint extends StatelessWidget {
  const _HowToHint({required this.tv, required this.touch});

  final bool tv;

  /// Controlador Toque: se toca a la derecha o a la izquierda.
  final bool touch;

  @override
  Widget build(BuildContext context) {
    Widget pill(Color color, IconData icon, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: tv
          ? [
              pill(AppColors.green, Icons.check, 'Correcto'),
              pill(AppColors.orange, Icons.skip_next, 'Pasar'),
            ]
          : touch
          ? [
              pill(
                AppColors.green,
                Icons.touch_app,
                'Toca a la derecha: Acierto',
              ),
              pill(
                AppColors.orange,
                Icons.touch_app,
                'Toca a la izquierda: Pasar',
              ),
            ]
          : [
              pill(AppColors.green, Icons.arrow_downward, 'Acierto'),
              pill(AppColors.orange, Icons.arrow_upward, 'Pasar'),
            ],
    );
  }
}

/// La cámara frontal en vivo, en horizontal, a pantalla completa y sin
/// deformarse.
class _CameraBackground extends StatelessWidget {
  const _CameraBackground({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.previewSize;
    if (size == null) return const SizedBox.shrink();
    final long = size.longestSide;
    final short = size.shortestSide;
    // La vista está fijada en horizontal (ver CameraService.initialize);
    // si no se pudo fijar, sigue la orientación de la pantalla.
    final landscape =
        controller.value.lockedCaptureOrientation != null ||
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: landscape ? long : short,
          height: landscape ? short : long,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

/// Arriba a la derecha sobre la cámara: "Cámara" con un punto verde.
class _CameraTag extends StatelessWidget {
  const _CameraTag();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x99000000),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 10, color: AppColors.green),
              SizedBox(width: 6),
              Text(
                'Cámara',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Con el controlador Toque, una marca suave en cada borde: "Pasar" a la
/// izquierda y "Acierto" a la derecha.
class _TouchMark extends StatelessWidget {
  const _TouchMark({required this.left});

  /// Ancho de la marca.
  static const width = 44.0;

  final bool left;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: IgnorePointer(
        child: Container(
          width: width,
          height: 180,
          decoration: BoxDecoration(
            color: (left ? AppColors.orange : AppColors.green).withValues(
              alpha: 0.35,
            ),
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(left ? 0 : 22),
              right: Radius.circular(left ? 22 : 0),
            ),
          ),
          child: RotatedBox(
            quarterTurns: left ? 3 : 1,
            child: Center(
              child: Text(
                left ? 'Pasar' : 'Acierto',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
