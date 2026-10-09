import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets/play_background.dart';

/// Elección de la categoría. "Libre" lleva a la configuración de siempre;
/// las demás se habilitan cuando esté el backend de palabras.
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  void _choose(BuildContext context, GameCategory category) {
    if (!category.available) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Muy pronto podrás jugar con ${category.label}.'),
          ),
        );
      return;
    }
    context.go(Routes.freeMode);
  }

  @override
  Widget build(BuildContext context) {
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Categorías'),
          leading: BackButton(onPressed: () => context.go(Routes.welcome)),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const Text(
                '¿Con qué palabras quieren jugar?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _CategoryCard(
                category: GameCategory.free,
                large: true,
                onTap: () => _choose(context, GameCategory.free),
              ),
              const SizedBox(height: 24),
              const Text(
                'Categorías',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.9,
                children: [
                  for (final category in GameCategory.themed)
                    _CategoryCard(
                      category: category,
                      onTap: () => _choose(context, category),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onTap,
    this.large = false,
  });

  final GameCategory category;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final onColor = category.color == AppColors.yellow
        ? AppColors.ink
        : Colors.white;
    final title = Text(
      category.label,
      maxLines: large ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: AppFonts.display,
        fontSize: large ? 30 : 20,
        fontWeight: FontWeight.w600,
        color: onColor,
      ),
    );
    final description = Text(
      category.description,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: large ? 15 : 13,
        fontWeight: FontWeight.w700,
        color: onColor.withValues(alpha: 0.85),
      ),
    );

    return Material(
      color: category.color,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: large
                  ? Row(
                      children: [
                        Icon(category.icon, size: 56, color: onColor),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [title, description],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, color: onColor),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(category.icon, size: 40, color: onColor),
                        const Spacer(),
                        Flexible(flex: 0, child: title),
                        Flexible(flex: 0, child: description),
                      ],
                    ),
            ),
            if (!category.available)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_clock, size: 14, color: category.color),
                      const SizedBox(width: 4),
                      Text(
                        'Pronto',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: category.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
