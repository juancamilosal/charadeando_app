import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Pestaña de la pantalla de categorías.
enum CategoryTab { all, mine }

/// Lo que se guarda en el archivo: las categorías propias y la última
/// pestaña elegida.
class CustomCategoriesData {
  const CustomCategoriesData({
    this.categories = const [],
    this.tab = CategoryTab.all,
  });

  final List<CustomCategory> categories;
  final CategoryTab tab;

  CustomCategoriesData copyWith({
    List<CustomCategory>? categories,
    CategoryTab? tab,
  }) => CustomCategoriesData(
    categories: categories ?? this.categories,
    tab: tab ?? this.tab,
  );
}

/// Guarda "Mis categorías" en un archivo del celular. No se suben a
/// Directus ni a ningún servidor: si se desinstala la app, se pierden.
class CustomCategoryStore {
  CustomCategoryStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const _fileName = 'mis_categorias.json';

  /// Categorías propias gratis. Null es sin límite; más adelante, por
  /// ejemplo, 1 gratis y el resto con premium.
  static const int? freeLimit = null;

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  Future<CustomCategoriesData> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const CustomCategoriesData();
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return const CustomCategoriesData();
      return CustomCategoriesData(
        categories: [
          for (final c in json['categorias'] as List? ?? const [])
            if (c is Map<String, dynamic>) CustomCategory.fromJson(c),
        ],
        tab: json['pestana'] == 'mias' ? CategoryTab.mine : CategoryTab.all,
      );
    } on Exception catch (e) {
      debugPrint('[Mis categorías] No se pudo leer el archivo: $e');
      return const CustomCategoriesData();
    }
  }

  Future<void> save(CustomCategoriesData data) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'pestana': data.tab == CategoryTab.mine ? 'mias' : 'todas',
          'categorias': [for (final c in data.categories) c.toJson()],
        }),
      );
    } on Exception catch (e) {
      debugPrint('[Mis categorías] No se pudo guardar: $e');
    }
  }
}

/// Reglas de las palabras de una categoría propia.
abstract final class CustomWords {
  static const _accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'à': 'a',
    'è': 'e',
    'ì': 'i',
    'ò': 'o',
    'ù': 'u',
  };

  /// Forma para comparar: sin mayúsculas, sin tildes y sin espacios de más.
  static String key(String word) {
    final lower = word.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return lower.split('').map((c) => _accents[c] ?? c).join();
  }

  /// Palabras escritas o pegadas, separadas por comas, punto y coma o
  /// saltos de línea.
  static List<String> parse(String text) => [
    for (final part in text.split(RegExp(r'[,;\n\r]+')))
      if (part.trim().isNotEmpty) part.trim().replaceAll(RegExp(r'\s+'), ' '),
  ];

  /// Agrega [incoming] a [existing] sin repetir (sin importar mayúsculas ni
  /// tildes). Devuelve la lista nueva y las que no se agregaron por estar
  /// repetidas.
  static ({List<String> words, List<String> repeated}) add(
    List<String> existing,
    Iterable<String> incoming,
  ) {
    final keys = {for (final w in existing) key(w)};
    final words = [...existing];
    final repeated = <String>[];
    for (final raw in incoming) {
      final w = raw.length > CustomCategory.maxWordLength
          ? raw.substring(0, CustomCategory.maxWordLength).trim()
          : raw;
      if (keys.add(key(w))) {
        words.add(w);
      } else {
        repeated.add(w);
      }
    }
    return (words: words, repeated: repeated);
  }
}
