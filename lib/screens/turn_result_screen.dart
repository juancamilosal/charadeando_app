import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
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
    final controller = ref.read(gameControllerProvider.notifier);
    final path = ref.read(gameControllerProvider).lastTurn?.videoPath;
    if (path != null) {
      await ref.read(videoServiceProvider).delete(path);
      controller.clearLastVideo();
    }
    controller.advance();
    if (!mounted) return;
    context.go(
      ref.read(gameControllerProvider).finished
          ? Routes.finalResult
          : Routes.turn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    final turn = game.lastTurn;
    if (turn == null) return const Scaffold();
    final theme = Theme.of(context);
    final mode = game.config.scoringMode;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      Text(
                        'Ronda ${turn.round} de ${game.config.rounds}',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        '${game.groups[turn.groupIndex].name}: '
                        '+${turn.points(mode)} puntos',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (turn.entries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No se marcó ninguna palabra.'),
                        ),
                      for (final entry in turn.entries)
                        _EntryTile(entry: entry, mode: mode),
                      const SizedBox(height: 16),
                      Text('Puntajes', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Scoreboard(
                        groups: game.groups,
                        scores: game.scores,
                        highlight: turn.groupIndex,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (turn.videoPath != null) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Ver video'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => context.push(Routes.video),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'El video se borra al continuar. Si lo quieres, guárdalo antes.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton.icon(
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continuar'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _leaving ? null : _continue,
                ),
              ],
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
        color: hit ? Colors.green : Colors.orange,
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
