import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets/play_background.dart';
import '../widgets/scoreboard.dart';

/// Ganador, o empate, y tabla de puntajes al terminar todas las rondas.
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
  }

  void _playAgain() {
    final controller = ref.read(gameControllerProvider.notifier);
    controller.configure(ref.read(gameControllerProvider).config);
    context.go(Routes.words);
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    final leaders = [for (final i in game.leaders) game.groups[i].name];
    final losers = [for (final i in game.losers) game.groups[i].name];
    final title = game.isTie
        ? '¡Empate entre ${_joinNames(leaders)}!'
        : '¡Ganó ${leaders.single}!';

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
                        const SizedBox(height: 24),
                        const Icon(
                          Icons.emoji_events,
                          size: 110,
                          color: AppColors.yellow,
                          shadows: [
                            Shadow(color: Colors.black26, blurRadius: 12),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Scoreboard(groups: game.groups, scores: game.scores),
                        if (_punished < losers.length) ...[
                          const SizedBox(height: 20),
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
              'Empataron con menos puntos: cada grupo gira su ruleta.',
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
