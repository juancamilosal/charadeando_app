import 'package:flutter/material.dart';

import '../theme.dart';

/// Categorías de palabras. En "Libre" los grupos escriben las palabras o
/// se descargan frases de la categoría LIBRE; las demás descargan palabras
/// de su categoría en Directus.
enum GameCategory {
  free(
    'Libre',
    'Escriban sus palabras o nosotros las ponemos.',
    Icons.edit_note,
    AppColors.yellow,
    'LIBRE',
  ),
  animals(
    'Animales',
    'Del perro a la jirafa',
    Icons.pets,
    AppColors.green,
    'ANIMALES',
  ),
  geography(
    'Geografía',
    'Países, ciudades, ríos y más',
    Icons.public,
    AppColors.pink,
    'GEOGRAFIA',
  ),
  movies(
    'Películas',
    'Clásicos y estrenos',
    Icons.movie,
    AppColors.magenta,
    'PELICULAS',
  ),
  celebrities(
    'Celebridades',
    'Famosos de todo tipo',
    Icons.star,
    AppColors.orange,
    'CELEBRIDADES',
  ),
  brands(
    'Marcas',
    'Las que todos conocen',
    Icons.local_offer,
    AppColors.turquoise,
    'MARCAS',
  ),
  sports(
    'Deportes',
    'A moverse',
    Icons.sports_basketball,
    AppColors.coral,
    'DEPORTES',
  ),
  soccerTeams(
    'Equipos de fútbol',
    'Para los futboleros',
    Icons.sports_soccer,
    AppColors.purple,
    'EQUIPOS_FUTBOL',
  );

  const GameCategory(
    this.label,
    this.description,
    this.icon,
    this.color,
    this.code,
  );

  final String label;
  final String description;
  final IconData icon;
  final Color color;

  /// Valor del campo `categoria` en Directus.
  final String code;

  /// Categorías con palabras del backend, sin contar "Libre".
  static List<GameCategory> get themed =>
      values.where((c) => c != GameCategory.free).toList();
}
