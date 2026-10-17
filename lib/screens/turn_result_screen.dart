import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme.dart';
import '../services/services.dart';
import '../widgets/backdrop_tile.dart';
import '../widgets/end_game_dialog.dart';
import '../widgets/play_background.dart';
import '../widgets/result_parts.dart';

/// Resultado de un turno: aciertos o puntos en grande, las palabras
/// acertadas y pasadas, el marcador y el video. Si una palabra se marcó
/// mal, se toca para cambiarla (y con el celular juez, él también puede
/// corregirlas desde su página; los cambios se ven en los dos lados). En la partida rápida, que
/// tiene un solo turno, es el resultado de la partida: sin ganador ni
/// ruleta, con "Otra rápida", "Personalizada" y "Salir de la categoría".
class TurnResultScreen extends ConsumerStatefulWidget {
  const TurnResultScreen({super.key});

  @override
  ConsumerState<TurnResultScreen> createState() => _TurnResultScreenState();
}

class _TurnResultScreenState extends ConsumerState<TurnResultScreen> {
  bool _leaving = false;

  /// Celular juez: la sala, si se juega con él, y lo último que se le
  /// mandó (para cerrarle las correcciones al salir).
  JudgeRoom? _judge;
  StreamSubscription<JudgeCorrection>? _corrections;
  JudgeState? _sent;

  @override
  void initState() {
    super.initState();
    final game = ref.read(gameControllerProvider);
    final judge = game.config.judgePhone
        ? ref.read(judgeProvider.notifier).room
        : null;
    _judge = judge;
    if (judge != null) {
      _corrections = judge.corrections.listen(
        (c) => _correct(
          c.index,
          c.hit ? WordOutcome.hit : WordOutcome.pass,
          byJudge: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _corrections?.cancel();
    // Al salir de aquí, el juez ya no puede corregir.
    final sent = _sent;
    if (sent != null && sent.editable) _judge?.send(sent.locked());
    super.dispose();
  }

  /// Si con este turno termina la partida.
  bool get _gameOver =>
      ref.read(gameControllerProvider).finished ||
      ref.read(gameControllerProvider.notifier).afterAdvance.finished;

  /// Le manda al juez el resumen del turno; con [editable], todavía puede
  /// corregirlo.
  void _syncJudge({required bool editable}) {
    final judge = _judge;
    if (judge == null) return;
    final summary = judgeTurnSummary(
      ref.read(gameControllerProvider),
      gameOver: _gameOver,
      editable: editable,
    );
    _sent = summary;
    judge.send(summary);
  }

  /// La palabra [index] se marcó mal: queda como [outcome]. Si la cambió
  /// el juez, se avisa.
  void _correct(int index, WordOutcome outcome, {bool byJudge = false}) {
    if (_leaving || !mounted) return;
    final turn = ref.read(gameControllerProvider).lastTurn;
    if (turn == null || index < 0 || index >= turn.entries.length) return;
    final word = turn.entries[index].word.text;
    ref.read(gameControllerProvider.notifier).correctLastTurn(index, outcome);
    _syncJudge(editable: true);
    if (byJudge) {
      final hit = outcome == WordOutcome.hit;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'El juez cambió "$word" a ${hit ? '✅ acertada' : '⏭️ pasada'}.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  /// Tocar una palabra la cambia entre acertada y pasada.
  void _toggle(int index) {
    final turn = ref.read(gameControllerProvider).lastTurn;
    if (turn == null || index >= turn.entries.length) return;
    final hit = turn.entries[index].outcome == WordOutcome.hit;
    _correct(index, hit ? WordOutcome.pass : WordOutcome.hit);
  }

  /// Al salir del resultado, el resumen del juez queda fijo.
  void _lockJudge({bool? gameOver}) {
    final judge = _judge;
    if (judge == null) return;
    final summary = judgeTurnSummary(
      ref.read(gameControllerProvider),
      gameOver: gameOver ?? _gameOver,
    );
    _sent = summary;
    judge.send(summary);
  }

  /// El video del turno se borra al continuar, salvo que el usuario lo haya
  /// guardado en la galería.
  Future<void> _continue() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    _lockJudge();
    await ref.read(turnVideoProvider.notifier).discard();
    ref.read(gameControllerProvider.notifier).advance();
    if (!mounted) return;
    context.go(
      ref.read(gameControllerProvider).finished
          ? Routes.finalResult
          : Routes.turn,
    );
  }

  /// "Finalizar juego": termina la partida con los puntajes de ahora.
  Future<void> _endGame() async {
    if (_leaving) return;
    if (!await confirmEndGame(context, played: true) || !mounted) return;
    setState(() => _leaving = true);
    _lockJudge(gameOver: true);
    await ref.read(turnVideoProvider.notifier).discard();
    ref.read(gameControllerProvider.notifier).endGame();
    if (mounted) context.go(Routes.finalResult);
  }

  /// Partida rápida: otra con la misma categoría y palabras nuevas.
  Future<void> _quickAgain() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    _lockJudge();
    await ref.read(turnVideoProvider.notifier).discard();
    if (!mounted) return;
    final config = ref.read(gameControllerProvider).config;
    ref.read(gameControllerProvider.notifier).configure(config);
    context.go(
      config.wordSource == WordSource.random ? Routes.autoWords : Routes.words,
    );
  }

  /// Partida rápida: la misma categoría, pero personalizada.
  Future<void> _custom() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    _lockJudge();
    await ref.read(turnVideoProvider.notifier).discard();
    if (!mounted) return;
    final config = ref.read(gameControllerProvider).config;
    ref
        .read(gameControllerProvider.notifier)
        .configure(QuickGame.custom(config));
    context.go(Routes.config);
  }

  /// Partida rápida: vuelve a Categorías.
  Future<void> _exit() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    _lockJudge();
    await ref.read(turnVideoProvider.notifier).discard();
    if (mounted) context.go(Routes.categories);
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    final video = ref.watch(turnVideoProvider);
    final turn = game.lastTurn;
    if (turn == null) return Scaffold();
    final config = game.config;
    final mode = config.scoringMode;
    final quick = config.quick;
    final hits = turn.hits.length;
    final passes = turn.passed.length;
    final String subtitle;
    if (quick) {
      subtitle = '${config.categoryLabel} · Partida rápida';
    } else {
      final round = config.roundLabel(turn.round);
      subtitle = game.inGroups
          ? '${game.groups[turn.groupIndex].name} · $round'
          : round;
    }
    final hasVideo = video.status != TurnVideoStatus.none;
    final muted = TextStyle(
      color: context.onBackdrop.withValues(alpha: 0.8),
      fontSize: 13,
    );

    return PopScope(
      canPop: false,
      child: PlayBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        ResultTitle(title: '¡Tiempo!', subtitle: subtitle),
                        const SizedBox(height: 8),
                        // Por frase cada acierto es un punto: se cuentan
                        // aciertos.
                        quick || mode == ScoringMode.perPhrase
                            ? BigScore(value: hits, label: 'Aciertos')
                            : BigScore(
                                value: turn.points(mode),
                                label: 'Puntos',
                              ),
                        const SizedBox(height: 12),
                        HitPassPills(hits: hits, passes: passes),
                        const SizedBox(height: 16),
                        if (turn.entries.isNotEmpty) ...[
                          Text(
                            'Toca una palabra si se marcó mal.',
                            textAlign: TextAlign.center,
                            style: muted,
                          ),
                          const SizedBox(height: 6),
                        ],
                        TurnWordsPanel(
                          entries: turn.entries,
                          mode: mode,
                          onToggle: _leaving ? null : _toggle,
                        ),
                        if (!quick && game.inGroups) ...[
                          const SizedBox(height: 14),
                          MiniScoreboard(
                            groups: game.groups,
                            scores: game.scores,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (hasVideo) ...[
                    VideoButton(video: video),
                    // En la rápida solo se avisa si algo salió mal.
                    if (!quick || !video.withWords) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${video.withWords ? '' : 'No se pudieron escribir las '
                                  'palabras en este video. '}'
                        'Se borra al ${quick ? 'salir' : 'continuar'}',
                        style: muted,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                  if (quick) ...[
                    PairButtons(
                      left: PairButton(
                        color: AppColors.orange,
                        emoji: '⚡',
                        label: 'Otra rápida',
                        onPressed: _leaving ? null : _quickAgain,
                      ),
                      right: PairButton(
                        color: AppColors.purple,
                        emoji: '⚙️',
                        label: 'Personalizada',
                        onPressed: _leaving ? null : _custom,
                      ),
                    ),
                    const SizedBox(height: 4),
                    QuietButton(
                      icon: Icons.arrow_back,
                      label: 'Salir de la categoría',
                      onPressed: _leaving ? null : _exit,
                    ),
                  ] else ...[
                    FilledButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(_nextLabel()),
                      onPressed: _leaving ? null : _continue,
                    ),
                    EndGameButton(onPressed: _leaving ? null : _endGame),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "Turno de Los Tigres", o "Ver resultados" si fue el último turno.
  String _nextLabel() {
    final next = ref.read(gameControllerProvider.notifier).afterAdvance;
    if (next.finished) return 'Ver resultados';
    return next.inGroups
        ? 'Turno de ${next.currentGroup.name}'
        : 'Siguiente turno';
  }
}
