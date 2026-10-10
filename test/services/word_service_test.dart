import 'dart:math';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/services/word_service.dart';
import 'package:flutter_test/flutter_test.dart';

List<Word> words(String prefix, int count) => [
  for (var i = 0; i < count; i++) Word('$prefix$i'),
];

void main() {
  final service = WordService(random: Random(1));

  test('con dos grupos, cada uno juega las palabras del otro', () {
    final decks = service.decksFromGroupWords([words('a', 3), words('b', 2)]);
    expect(decks[0].map((w) => w.text), unorderedEquals(['b0', 'b1']));
    expect(decks[1].map((w) => w.text), unorderedEquals(['a0', 'a1', 'a2']));
  });

  test('con varios grupos, las palabras se reparten entre todos los '
      'rivales', () {
    final written = [words('a', 15), words('b', 15), words('c', 15)];
    final decks = service.decksFromGroupWords(written);

    for (var g = 0; g < 3; g++) {
      final prefix = 'abc'[g];
      // Nunca le salen sus propias palabras.
      expect(decks[g].where((w) => w.text.startsWith(prefix)), isEmpty);
      // Recibe palabras de los dos rivales y un mazo del mismo tamaño.
      final authors = decks[g].map((w) => w.text[0]).toSet();
      expect(authors, hasLength(2));
      expect(decks[g], hasLength(15));
    }
    // Cada palabra se juega una sola vez.
    final all = decks.expand((d) => d).map((w) => w.text).toList();
    expect(all, hasLength(45));
    expect(all.toSet(), hasLength(45));
  });

  test('nombra a los rivales', () {
    const two = [Group('A'), Group('B')];
    const three = [Group('A'), Group('B'), Group('C')];
    expect(WordService.rivalsLabel(0, two), 'B');
    expect(WordService.rivalsLabel(1, two), 'A');
    expect(WordService.rivalsLabel(2, three), 'los demás grupos');
  });

  test('reparte las palabras automáticas sin repetir', () {
    final decks = service.decksFromWords(words('w', 10), 3);
    expect(decks.map((d) => d.length), [4, 3, 3]);
    final all = decks.expand((d) => d).toList();
    expect(all.toSet(), hasLength(10));
  });
}
