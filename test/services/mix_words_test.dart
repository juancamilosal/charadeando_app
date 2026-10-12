import 'dart:math';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

List<Word> words(String category, int count) => [
  for (var i = 0; i < count; i++) Word('$category $i', category: category),
];

Map<String?, int> byCategory(List<Word> list) {
  final counts = <String?, int>{};
  for (final w in list) {
    counts[w.category] = (counts[w.category] ?? 0) + 1;
  }
  return counts;
}

final family = CustomCategory(
  id: 'f1',
  name: 'Mi familia',
  words: [for (var i = 0; i < 12; i++) 'Primo $i'],
);

void main() {
  test('reparte en partes iguales y el sobrante de a una', () {
    expect(MixWords.quotas(45, 3), [15, 15, 15]);
    expect(MixWords.quotas(46, 3), [16, 15, 15]);
    expect(MixWords.quotas(47, 3), [16, 16, 15]);
    expect(MixWords.quotas(10, 0), isEmpty);
  });

  test('toma lo mismo de cada categoría y las baraja juntas', () {
    final mixed = MixWords.combine(
      [words('ANIMALES', 40), words('PELICULAS', 40), words('DEPORTES', 40)],
      total: 45,
      random: Random(1),
    );
    expect(mixed, hasLength(45));
    expect(byCategory(mixed), {
      'ANIMALES': 15,
      'PELICULAS': 15,
      'DEPORTES': 15,
    });
    // Barajadas: no salen todas las de una categoría seguidas.
    expect(
      mixed.take(15).every((w) => w.category == mixed.first.category),
      isFalse,
    );
  });

  test('si una categoría no alcanza, se completa con las otras', () {
    final mixed = MixWords.combine(
      [words('ANIMALES', 5), words('PELICULAS', 40), words('DEPORTES', 40)],
      total: 45,
      random: Random(2),
    );
    expect(mixed, hasLength(45));
    final counts = byCategory(mixed);
    expect(counts['ANIMALES'], 5);
    expect(counts['PELICULAS']! + counts['DEPORTES']!, 40);
    expect((counts['PELICULAS']! - counts['DEPORTES']!).abs(), lessThan(2));
  });

  test('mezcla propias con las del juego y cada palabra conserva su '
      'categoría', () {
    final config = GameConfig(
      wordSource: WordSource.random,
      mixCategories: const [GameCategory.movies],
      mixCustom: [family],
    );
    final mixed = MixWords.combine(
      [words('PELICULAS', 30), MixWords.customWords(family)],
      total: 20,
      random: Random(3),
    );
    expect(byCategory(mixed), {'PELICULAS': 10, 'mia:f1': 10});
    final movie = mixed.firstWhere((w) => w.category == 'PELICULAS');
    final mine = mixed.firstWhere((w) => w.category == 'mia:f1');
    expect(config.wordCategoryLabel(movie), 'Película');
    expect(config.wordCategoryLabel(mine), 'Mi familia');
  });

  test('a Directus se le piden también las que les faltan a las propias', () {
    // 30 entre 3: 10 por categoría; la propia solo tiene 4.
    expect(MixWords.remoteCount(30, gameCategories: 2, customSizes: [4]), 26);
    expect(MixWords.remoteCount(30, gameCategories: 2, customSizes: [50]), 20);
    expect(MixWords.remoteCount(30, gameCategories: 0, customSizes: [4, 9]), 0);
  });

  test('la dificultad aplica solo si hay categorías del juego', () {
    final onlyMine = GameConfig(
      wordSource: WordSource.random,
      mixCustom: [
        family,
        CustomCategory(id: 'f2', name: 'La oficina', words: family.words),
      ],
    );
    expect(onlyMine.isMix, isTrue);
    expect(onlyMine.usesDifficulty, isFalse);
    final mixed = GameConfig(
      wordSource: WordSource.random,
      mixCategories: const [GameCategory.animals],
      mixCustom: [family],
    );
    expect(mixed.usesDifficulty, isTrue);
  });

  test('el nombre de la mezcla', () {
    final three = GameConfig(
      mixCategories: const [GameCategory.animals, GameCategory.movies],
      mixCustom: [family],
    );
    expect(three.categoryLabel, 'Mezcla: Animales, Películas y Mi familia');
    final five = GameConfig(
      mixCategories: const [
        GameCategory.animals,
        GameCategory.movies,
        GameCategory.sports,
        GameCategory.brands,
        GameCategory.geography,
      ],
    );
    expect(five.categoryLabel, 'Mezcla de 5 categorías');
    // Una sola categoría no es mezcla.
    const single = GameConfig(category: GameCategory.animals);
    expect(single.isMix, isFalse);
    expect(single.categoryLabel, 'Animales');
    expect(
      single.wordCategoryLabel(Word('León', category: 'ANIMALES')),
      isNull,
    );
  });
}
