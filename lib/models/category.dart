import 'package:flutter/material.dart';

import '../theme.dart';

/// Categorías de palabras. "Libre" es la que ya existe: los grupos escriben
/// las palabras o se descargan de todas las categorías. Las demás llegan
/// cuando haya palabras suficientes de cada una.
enum GameCategory {
  free(
    'Libre',
    'Escriban sus palabras o nosotros las ponemos.',
    Icons.edit_note,
    AppColors.yellow,
    available: true,
  ),
  animals('Animales', 'Del perro a la jirafa', Icons.pets, AppColors.green),
  geography(
    'Geografía',
    'Países, ciudades, ríos y más',
    Icons.public,
    AppColors.blue,
  ),
  movies('Películas', 'Clásicos y estrenos', Icons.movie, AppColors.magenta),
  celebrities(
    'Celebridades',
    'Famosos de todo tipo',
    Icons.star,
    AppColors.orange,
  ),
  brands(
    'Marcas',
    'Las que todos conocen',
    Icons.local_offer,
    AppColors.turquoise,
  ),
  sports('Deportes', 'A moverse', Icons.sports_basketball, AppColors.coral),
  soccerTeams(
    'Equipos de fútbol',
    'Para los futboleros',
    Icons.sports_soccer,
    AppColors.purple,
  );

  const GameCategory(
    this.label,
    this.description,
    this.icon,
    this.color, {
    this.available = false,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color color;

  /// Falso mientras la categoría no tenga palabras.
  final bool available;

  /// Categorías con palabras del backend, sin contar "Libre".
  static List<GameCategory> get themed =>
      values.where((c) => c != GameCategory.free).toList();
}
