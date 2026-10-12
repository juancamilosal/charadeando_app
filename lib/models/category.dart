import 'package:flutter/material.dart';

import '../theme.dart';

/// Categorías de palabras. En "Libre" los grupos escriben las palabras o
/// se descargan frases de la categoría LIBRE; las demás descargan palabras
/// de su categoría en Directus.
enum GameCategory {
  free(
    'Libre',
    'Sus palabras o las nuestras',
    Icons.edit_note,
    AppColors.blue,
    'LIBRE',
    'Palabra',
  ),
  animals(
    'Animales',
    'Del perro a la jirafa',
    Icons.pets,
    AppColors.green,
    'ANIMALES',
    'Animal',
  ),
  geography(
    'Geografía',
    'Países, ciudades, ríos y más',
    Icons.public,
    AppColors.indigo,
    'GEOGRAFIA',
    'Geografía',
  ),
  movies(
    'Películas',
    'Clásicos y estrenos',
    Icons.movie,
    AppColors.teal,
    'PELICULAS',
    'Película',
  ),
  celebrities(
    'Celebridades',
    'Famosos de todo tipo',
    Icons.star,
    AppColors.orange,
    'CELEBRIDADES',
    'Famoso',
  ),
  brands(
    'Marcas',
    'Las que todos conocen',
    Icons.local_offer,
    AppColors.turquoise,
    'MARCAS',
    'Marca',
  ),
  sports(
    'Deportes',
    'A moverse',
    Icons.sports_basketball,
    AppColors.navy,
    'DEPORTES',
    'Deporte',
  ),
  soccerTeams(
    'Equipos de fútbol',
    'Para los futboleros',
    Icons.sports_soccer,
    AppColors.purple,
    'EQUIPOS_FUTBOL',
    'Equipo de fútbol',
  ),
  objects(
    'Objetos',
    'Cosas de todos los días',
    Icons.key,
    AppColors.coral,
    'OBJETOS',
    'Objeto',
  ),
  food(
    'Comida',
    'Para chuparse los dedos',
    Icons.lunch_dining,
    AppColors.tomato,
    'COMIDA',
    'Comida',
  ),
  professions(
    'Profesiones',
    '¿A qué te dedicas?',
    Icons.work,
    AppColors.brown,
    'PROFESIONES',
    'Profesión',
  ),
  actions(
    'Acciones',
    '¡A actuar!',
    Icons.directions_run,
    AppColors.magenta,
    'ACCIONES',
    'Acción',
  ),
  places(
    'Lugares',
    'De la casa al fin del mundo',
    Icons.place,
    AppColors.forest,
    'LUGARES',
    'Lugar',
  );

  const GameCategory(
    this.label,
    this.description,
    this.icon,
    this.color,
    this.code,
    this.singular,
  );

  final String label;
  final String description;
  final IconData icon;
  final Color color;

  /// Valor del campo `categoria` en Directus.
  final String code;

  /// Nombre de una sola palabra de la categoría ("Película"), para mostrar
  /// arriba de la palabra en una partida con varias categorías.
  final String singular;

  /// Se desbloquea con premium. Por ahora ninguna lo es; cuando se definan
  /// las de pago, se marcan aquí.
  bool get premium => false;

  static GameCategory? byCode(String? code) {
    for (final c in values) {
      if (c.code == code) return c;
    }
    return null;
  }

  /// Categorías con palabras del backend, sin contar "Libre".
  static List<GameCategory> get themed =>
      values.where((c) => c != GameCategory.free).toList();
}
