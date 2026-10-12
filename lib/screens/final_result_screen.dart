import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../router.dart';
import '../theme.dart';
import '../models/models.dart';
import '../widgets/backdrop_tile.dart';
import '../widgets/play_background.dart';
import '../widgets/result_parts.dart';
import '../widgets/scoreboard.dart';

/// Ganador (o empate) con sus puntos en grande, la tabla de puntajes, la
/// ruleta de castigo y "Jugar otra vez" o "Cambiar configuración".
class FinalResultScreen extends ConsumerStatefulWidget {
  const FinalResultScreen({super.key});

  @override
  ConsumerState<FinalResultScreen> createState() => _FinalResultScreenState();
}

class _FinalResultScreenState extends ConsumerState<FinalResultScreen> {
  /// Cuántos de los grupos con menos puntos ya giraron (o saltaron) su
  /// ruleta de castigo. Giran uno después del otro.
  int _punished = 0;

  Future<void> _spin(String group) async {
    await context.push<bool>(Routes.punishmentSpin, extra: group);
    if (mounted) setState(() => _punished++);
  }

  @override
  void initState() {
    super.initState();
    // Por si quedó algún video temporal de la partida.
    ref.read(videoServiceProvider).deleteAll().ignore();
    // La partida se suma al historial de los equipos guardados.
    ref.read(gameControllerProvider.notifier).saveHistory().ignore();
  }

  /// Otra partida con la misma configuración: las palabras se vuelven a
  /// escribir o a pedir.
  void _playAgain() {
    final config = ref.read(gameControllerProvider).config;
    ref.read(gameControllerProvider.notifier).configure(config);
    context.go(
      config.wordSource == WordSource.random ? Routes.autoWords : Routes.words,
    );
  }

  /// A la configuración, con la de esta partida.
  void _changeConfig() {
    final config = ref.read(gameControllerProvider).config;
    ref.read(gameControllerProvider.notifier).configure(config);
    context.go(Routes.config);
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    final leaders = [for (final i in game.leaders) game.groups[i].name];
    final losers = [for (final i in game.losers) game.groups[i].name];
    // Sin grupos no hay ganador ni castigo: solo el total.
    final title = !game.inGroups
        ? '¡Fin del juego!'
        : game.isTie
        ? '¡Empate entre ${_joinNames(leaders)}!'
        : '¡Ganó ${leaders.single}!';

    final scores = game.scores;
    final best = game.inGroups ? scores[game.leaders.first] : game.totalScore;
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
                        Icon(
                          Icons.emoji_events,
                          size: 72,
                          color: context.backdrop.light
                              ? AppColors.orange
                              : AppColors.yellow,
                          shadows: const [
                            Shadow(color: Colors.black26, blurRadius: 12),
                          ],
                        ),
                        ResultTitle(title: title),
                        const SizedBox(height: 4),
                        BigScore(
                          value: best,
                          label: best == 1 ? 'Punto' : 'Puntos',
                        ),
                        if (game.inGroups) ...[
                          const SizedBox(height: 16),
                          Scoreboard(
                            groups: game.groups,
                            scores: scores,
                            // El primero, resaltado.
                            highlight: game.isTie ? null : game.leaders.single,
                          ),
                        ],
                        if (_punished < losers.length) ...[
                          const SizedBox(height: 16),
                          _PunishmentCard(
                            group: losers[_punished],
                            tied: losers.length > 1,
                            onSpin: () => _spin(losers[_punished]),
                            onSkip: () => setState(() => _punished++),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PairButtons(
                    left: PairButton(
                      color: AppColors.orange,
                      emoji: '🔁',
                      label: 'Jugar otra vez',
                      onPressed: _playAgain,
                    ),
                    right: PairButton(
                      color: AppColors.purple,
                      emoji: '⚙️',
                      label: 'Cambiar configuración',
                      onPressed: _changeConfig,
                    ),
                  ),
                  const SizedBox(height: 4),
                  QuietButton(
                    icon: Icons.arrow_back,
                    label: 'Salir de la categoría',
                    onPressed: () => context.go(Routes.categories),
                  ),
                ],
              ),
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

/// Invitación a girar la ruleta de castigo para el grupo con menos puntos.
class _PunishmentCard extends StatelessWidget {
  const _PunishmentCard({
    required this.group,
    required this.tied,
    required this.onSpin,
    required this.onSkip,
  });

  final String group;

  /// Varios grupos empataron con menos puntos: cada uno gira su ruleta.
  final bool tied;
  final VoidCallback onSpin;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.casino, size: 40, color: AppColors.coral),
          Text(
            '¡Ruleta de castigo para $group!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (tied)
            const Text(
              'Empataron con menos puntos: cada equipo gira su ruleta.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B5A86)),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.autorenew),
            label: const Text('Girar'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: Colors.white,
            ),
            onPressed: onSpin,
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.purple),
            onPressed: onSkip,
            child: const Text('Sin castigo'),
          ),
        ],
      ),
    );
  }
}
