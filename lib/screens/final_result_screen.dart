import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../router.dart';
import '../widgets/scoreboard.dart';

/// Ganador, o empate, y tabla de puntajes al terminar todas las rondas.
class FinalResultScreen extends ConsumerStatefulWidget {
  const FinalResultScreen({super.key});

  @override
  ConsumerState<FinalResultScreen> createState() => _FinalResultScreenState();
}

class _FinalResultScreenState extends ConsumerState<FinalResultScreen> {
  @override
  void initState() {
    super.initState();
    // Por si quedó algún video temporal de la partida.
    ref.read(videoServiceProvider).deleteAll().ignore();
  }

  void _playAgain() {
    final controller = ref.read(gameControllerProvider.notifier);
    controller.configure(ref.read(gameControllerProvider).config);
    context.go(Routes.words);
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    final theme = Theme.of(context);
    final leaders = [for (final i in game.leaders) game.groups[i].name];
    final title = game.isTie
        ? '¡Empate entre ${_joinNames(leaders)}!'
        : '¡Ganó ${leaders.single}!';

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
                      const SizedBox(height: 24),
                      Icon(
                        Icons.emoji_events,
                        size: 72,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Scoreboard(groups: game.groups, scores: game.scores),
                    ],
                  ),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.replay),
                  label: const Text('Jugar otra vez'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _playAgain,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go(Routes.welcome),
                  child: const Text('Volver al inicio'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _joinNames(List<String> names) => names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} y ${names.last}';
}
