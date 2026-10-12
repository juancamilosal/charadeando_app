import 'package:flutter/material.dart';

import '../theme.dart';

/// Categorías de palabras. En "Libre" los grupos escriben las palabras o
/// se descargan frases de la categoría LIBRE; las demás descargan palabras
/// de su categoría en Directus.
enum GameCategory {
  free('Libre', Icons.edit_note, AppColors.blue, 'LIBRE', 'Palabra'),
  animals('Animales', Icons.pets, AppColors.green, 'ANIMALES', 'Animal'),
  geography(
    'Geografía',
    Icons.public,
    AppColors.indigo,
    'GEOGRAFIA',
    'Geografía',
  ),
  movies('Películas', Icons.movie, AppColors.teal, 'PELICULAS', 'Película'),
  celebrities(
    'Celebridades',
    Icons.star,
    AppColors.orange,
    'CELEBRIDADES',
    'Famoso',
  ),
  brands('Marcas', Icons.local_offer, AppColors.turquoise, 'MARCAS', 'Marca'),
  sports(
    'Deportes',
    Icons.sports_basketball,
    AppColors.navy,
    'DEPORTES',
    'Deporte',
  ),
  soccerTeams(
    'Equipos de fútbol',
    Icons.sports_soccer,
    AppColors.purple,
    'EQUIPOS_FUTBOL',
    'Equipo de fútbol',
  ),
  objects('Objetos', Icons.key, AppColors.coral, 'OBJETOS', 'Objeto'),
  food('Comida', Icons.lunch_dining, AppColors.tomato, 'COMIDA', 'Comida'),
  professions(
    'Profesiones',
    Icons.work,
    AppColors.brown,
    'PROFESIONES',
    'Profesión',
  ),
  actions(
    'Acciones',
    Icons.directions_run,
    AppColors.magenta,
    'ACCIONES',
    'Acción',
  ),
  places('Lugares', Icons.place, AppColors.forest, 'LUGARES', 'Lugar');

  const GameCategory(
    this.label,
    this.icon,
    this.color,
    this.code,
    this.singular,
  );

  final String label;
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
