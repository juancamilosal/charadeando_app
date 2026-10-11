import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets/end_game_dialog.dart';
import '../widgets/play_background.dart';
import '../widgets/scoreboard.dart';

/// Palabras acertadas y pasadas del turno, más los puntajes de todos.
class TurnResultScreen extends ConsumerStatefulWidget {
  const TurnResultScreen({super.key});

  @override
  ConsumerState<TurnResultScreen> createState() => _TurnResultScreenState();
}

class _TurnResultScreenState extends ConsumerState<TurnResultScreen> {
  bool _leaving = false;

  /// El video del turno se borra al continuar, salvo que el usuario lo haya
  /// guardado en la galería.
  Future<void> _continue() async {
    if (_leaving) return;
    setState(() => _leaving = true);
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
    await ref.read(turnVideoProvider.notifier).discard();
    ref.read(gameControllerProvider.notifier).endGame();
    if (mounted) context.go(Routes.finalResult);
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    final video = ref.watch(turnVideoProvider);
    final turn = game.lastTurn;
    if (turn == null) return Scaffold();
    final mode = game.config.scoringMode;

    final white = TextStyle(
      color: context.onBackdrop,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    return PopScope(
      canPop: false,
      child: PlayBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        Text(game.config.roundLabel(turn.round), style: white),
                        Text(
                          game.inGroups
                              ? '${game.groups[turn.groupIndex].name}: '
                                    '+${turn.points(mode)} puntos'
                              : '+${turn.points(mode)} puntos',
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            color: context.onBackdrop,
                          ),
                        ),
                        const SizedBox(height: 12),
                        PlayPanel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: turn.entries.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('No se marcó ninguna palabra.'),
                                )
                              : Column(
                                  children: [
                                    for (final entry in turn.entries)
                                      _EntryTile(entry: entry, mode: mode),
                                  ],
                                ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          game.inGroups
                              ? 'Puntajes'
                              : 'Total: ${game.totalScore} puntos',
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: context.onBackdrop,
                          ),
                        ),
                        // Sin grupos no hay tabla: solo el total.
                        if (game.inGroups) ...[
                          const SizedBox(height: 8),
                          Scoreboard(
                            groups: game.groups,
                            scores: game.scores,
                            highlight: turn.groupIndex,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  if (video.status != TurnVideoStatus.none) ...[
                    _VideoButton(video: video),
                    SizedBox(height: 6),
                    Text(
                      video.withWords
                          ? 'El video se borra al continuar. Si lo quieres, guárdalo antes.'
                          : 'No se pudieron escribir las palabras en este video. '
                                'Se borra al continuar.',
                      style: TextStyle(color: context.onBackdrop, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                  ],
                  FilledButton.icon(
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Continuar'),
                    onPressed: _leaving ? null : _continue,
                  ),
                  EndGameButton(onPressed: _leaving ? null : _endGame),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.mode});

  final TurnEntry entry;
  final ScoringMode mode;

  @override
  Widget build(BuildContext context) {
    final hit = entry.outcome == WordOutcome.hit;
    return ListTile(
      dense: true,
      leading: Icon(
        hit ? Icons.check_circle : Icons.skip_next,
        color: hit ? AppColors.green : AppColors.orange,
      ),
      title: Text(
        entry.word.text,
        style: hit
            ? null
            : const TextStyle(decoration: TextDecoration.lineThrough),
      ),
      trailing: Text(hit ? '+${mode.pointsFor(entry.word.wordCount)}' : '0'),
    );
  }
}

/// "Ver video", o el avance mientras se escriben las palabras en el video.
class _VideoButton extends StatelessWidget {
  const _VideoButton({required this.video});

  final TurnVideoState video;

  @override
  Widget build(BuildContext context) {
    if (video.status == TurnVideoStatus.ready) {
      return OutlinedButton.icon(
        icon: Icon(Icons.play_circle_outline),
        label: Text('Ver video'),
        onPressed: () => context.push(Routes.video),
      );
    }
    final percent = (video.progress * 100).round();
    return OutlinedButton.icon(
      icon: SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: context.onBackdrop,
          value: video.progress > 0 ? video.progress : null,
        ),
      ),
      label: Text('Preparando video… $percent%'),
      style: OutlinedButton.styleFrom(
        disabledForegroundColor: context.onBackdrop.withValues(alpha: 0.8),
        side: BorderSide(
          color: context.onBackdrop.withValues(alpha: 0.55),
          width: 2,
        ),
      ),
      onPressed: null,
    );
  }
}
