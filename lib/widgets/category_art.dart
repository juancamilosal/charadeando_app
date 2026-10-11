import 'package:flutter/material.dart';

import '../models/models.dart';

/// Dibujo animado de la categoría (`assets/img/categorias/<categoría>.gif`).
/// Las categorías que todavía no tienen GIF muestran su ícono.
class CategoryArt extends StatelessWidget {
  const CategoryArt({
    super.key,
    required this.category,
    required this.size,
    this.color = Colors.white,
  });

  /// Categorías que ya tienen su GIF en la carpeta.
  static const _animated = {GameCategory.animals, GameCategory.geography};

  final GameCategory category;
  final double size;

  /// Color del ícono cuando no hay GIF.
  final Color color;

  static String asset(GameCategory category) =>
      'assets/img/categorias/${category.code.toLowerCase()}.gif';

  @override
  Widget build(BuildContext context) {
    if (!_animated.contains(category)) {
      return Icon(category.icon, size: size, color: color);
    }
    return Image.asset(
      asset(category),
      width: size,
      height: size,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => Icon(category.icon, size: size, color: color),
    );
  }
}
