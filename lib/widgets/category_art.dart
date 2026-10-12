import 'package:flutter/material.dart';

import '../models/models.dart';

/// Dibujo de la categoría: una imagen quieta
/// (`assets/img/categorias/<código>.png`). Las que todavía no tienen
/// imagen muestran su ícono.
class CategoryArt extends StatelessWidget {
  const CategoryArt({
    super.key,
    required this.category,
    required this.size,
    this.color = Colors.white,
  });

  /// Categorías que ya tienen su imagen en la carpeta. Para agregar una,
  /// se pone su PNG con el código de la categoría en minúsculas y se suma
  /// aquí.
  static const withImage = {
    GameCategory.free,
    GameCategory.animals,
    GameCategory.geography,
    GameCategory.movies,
    GameCategory.celebrities,
    GameCategory.brands,
    GameCategory.sports,
    GameCategory.soccerTeams,
    GameCategory.objects,
    GameCategory.food,
    GameCategory.professions,
    GameCategory.actions,
    GameCategory.places,
    GameCategory.seriesNovels,
    GameCategory.characters,
    GameCategory.superheroes,
    GameCategory.cartoons,
    GameCategory.videogames,
    GameCategory.music,
    GameCategory.historicalFigures,
    GameCategory.sayings,
    GameCategory.halloween,
    GameCategory.christmas,
  };

  final GameCategory category;
  final double size;

  /// Color del ícono cuando no hay imagen.
  final Color color;

  static String asset(GameCategory category) =>
      'assets/img/categorias/${category.code.toLowerCase()}.png';

  @override
  Widget build(BuildContext context) {
    final icon = Icon(category.icon, size: size, color: color);
    if (!withImage.contains(category)) return icon;
    return Image.asset(
      asset(category),
      width: size,
      height: size,
      errorBuilder: (_, _, _) => icon,
    );
  }
}
