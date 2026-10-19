import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets/category_art.dart';
import '../widgets/play_background.dart';
import '../widgets/play_choice.dart';

/// Categoría Libre: se elige de dónde salen las palabras, escritas por los
/// grupos o automáticas, y se sigue a la configuración.
class FreeModeScreen extends ConsumerWidget {
  const FreeModeScreen({super.key});

  void _choose(BuildContext context, WidgetRef ref, WordSource source) {
    ref
        .read(gameControllerProvider.notifier)
        .configure(
          ref.read(gameControllerProvider).config.copyWith(wordSource: source),
        );
    choosePlay(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Libre'),
          leading: BackButton(onPressed: () => context.go(Routes.categories)),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Center(
                child: CategoryArt(category: GameCategory.free, size: 120),
              ),
              const SizedBox(height: 8),
              Text(
                '¿Cómo quieren las palabras?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: context.onBackdrop,
                ),
              ),
              const SizedBox(height: 14),
              _ModeCard(
                icon: Icons.edit,
                color: AppColors.purple,
                title: 'Las escribimos',
                description: 'Antes de empezar',
                onTap: () => _choose(context, ref, WordSource.groups),
              ),
              const SizedBox(height: 12),
              _ModeCard(
                icon: Icons.casino,
                color: AppColors.turquoise,
                title: 'Al azar',
                description: 'El juego las pone, listas para jugar',
                onTap: () => _choose(context, ref, WordSource.random),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(icon, size: 44, color: color),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: color),
                    const SizedBox(width: 6),
                    Text(
                      'ELEGIR',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
