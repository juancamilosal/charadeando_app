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
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        icon: const Icon(Icons.replay),
                        label: const Text('Jugar otra vez'),
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
                const SizedBox(width: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Scoreboard(groups: game.groups, scores: game.scores),
                  ),
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
