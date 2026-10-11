import 'package:flutter/material.dart';

import '../theme.dart';

/// Categoría creada por el usuario, con sus propias palabras. Se guarda
/// solo en el celular.
class CustomCategory {
  const CustomCategory({
    required this.id,
    required this.name,
    required this.words,
    this.description = '',
    this.colorIndex = 0,
    this.iconKey = 'family',
  });

  factory CustomCategory.fromJson(Map<String, dynamic> json) => CustomCategory(
    id: json['id'] as String? ?? '',
    name: json['nombre'] as String? ?? '',
    description: json['descripcion'] as String? ?? '',
    colorIndex: (json['color'] as num?)?.toInt() ?? 0,
    iconKey: json['icono'] as String? ?? 'family',
    words: [
      for (final w in json['palabras'] as List? ?? const [])
        if (w is String && w.trim().isNotEmpty) w.trim(),
    ],
  );

  static const maxNameLength = 24;
  static const maxDescriptionLength = 60;
  static const maxWordLength = 40;

  /// Palabras necesarias para poder jugar.
  static const minWords = 10;

  /// Con estas o más, las palabras no se repiten tan rápido.
  static const suggestedWords = 30;

  /// Colores que se pueden elegir, de la paleta de la app.
  static const colors = [
    AppColors.purple,
    AppColors.magenta,
    AppColors.pink,
    AppColors.coral,
    AppColors.orange,
    AppColors.green,
    AppColors.turquoise,
    AppColors.teal,
    AppColors.blue,
    AppColors.navy,
    AppColors.indigo,
  ];

  /// Íconos que se pueden elegir, por clave (lo que se guarda).
  static const icons = <String, IconData>{
    'family': Icons.family_restroom,
    'home': Icons.home,
    'work': Icons.work,
    'flight': Icons.flight,
    'party': Icons.celebration,
    'food': Icons.restaurant,
    'music': Icons.music_note,
    'sports': Icons.sports_soccer,
    'school': Icons.school,
    'heart': Icons.favorite,
    'pet': Icons.pets,
    'beach': Icons.beach_access,
    'movie': Icons.movie,
    'game': Icons.sports_esports,
    'book': Icons.menu_book,
    'star': Icons.star,
    'gift': Icons.card_giftcard,
    'car': Icons.directions_car,
    'nature': Icons.park,
    'friends': Icons.groups,
  };

  final String id;
  final String name;
  final String description;
  final int colorIndex;
  final String iconKey;
  final List<String> words;

  Color get color => colors[colorIndex % colors.length];
  IconData get icon => icons[iconKey] ?? Icons.category;

  /// Palabras que faltan para poder jugar (0 si ya alcanza).
  int get missingWords =>
      words.length >= minWords ? 0 : minWords - words.length;
  bool get playable => missingWords == 0;

  /// "24 palabras", "1 palabra".
  String get wordsLabel =>
      words.length == 1 ? '1 palabra' : '${words.length} palabras';

  CustomCategory copyWith({
    String? name,
    String? description,
    int? colorIndex,
    String? iconKey,
    List<String>? words,
  }) => CustomCategory(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    colorIndex: colorIndex ?? this.colorIndex,
    iconKey: iconKey ?? this.iconKey,
    words: words ?? this.words,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': name,
    'descripcion': description,
    'color': colorIndex,
    'icono': iconKey,
    'palabras': words,
  };

  @override
  bool operator ==(Object other) => other is CustomCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
