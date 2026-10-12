import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'category_art.dart';

/// Arriba de la configuración: el dibujo de la categoría y su
/// nombre. Una categoría propia muestra su ícono en su color; una mezcla, los
/// dibujos de las categorías elegidas.
class CategoryHeader extends StatelessWidget {
  const CategoryHeader({super.key, required this.config, this.artSize = 120});

  final GameConfig config;

  /// Tamaño del dibujo de una categoría del juego.
  final double artSize;

  @override
  Widget build(BuildContext context) {
    final custom = config.customCategory;
    final Widget art;
    if (config.isMix) {
      art = Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in config.mixCategories)
            _Badge(
              color: c.color,
              child: CategoryArt(category: c, size: 48),
            ),
          for (final c in config.mixCustom)
            _Badge(
              color: c.color,
              child: Icon(c.icon, color: Colors.white, size: 36),
            ),
        ],
      );
    } else if (custom != null) {
      art = Container(
        width: artSize * 0.92,
        height: artSize * 0.92,
        decoration: BoxDecoration(
          color: custom.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Icon(custom.icon, size: artSize / 2, color: Colors.white),
      );
    } else {
      art = CategoryArt(
        category: config.category,
        size: artSize,
        color: context.onBackdrop,
      );
    }
    return Column(
      children: [
        art,
        const SizedBox(height: 6),
        Text(
          config.categoryLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: config.isMix ? 22 : 30,
            fontWeight: FontWeight.w600,
            color: context.onBackdrop,
          ),
        ),
      ],
    );
  }
}

/// Dibujo pequeño de una categoría de la mezcla, en un cuadro de su color.
class _Badge extends StatelessWidget {
  const _Badge({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(child: child),
    );
  }
}
