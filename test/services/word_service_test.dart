import 'dart:math';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/services/word_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada grupo juega las palabras que escribió el grupo anterior', () {
    final service = WordService(random: Random(1));
    final decks = service.decksFromGroupWords([
      [Word('a1'), Word('a2')],
      [Word('b1')],
      [Word('c1'), Word('c2'), Word('c3')],
    ]);
    expect(decks[0].map((w) => w.text), unorderedEquals(['c1', 'c2', 'c3']));
    expect(decks[1].map((w) => w.text), unorderedEquals(['a1', 'a2']));
    expect(decks[2].map((w) => w.text), ['b1']);
  });

  test('targetOf da la vuelta al último grupo', () {
    expect(WordService.targetOf(0, 3), 1);
    expect(WordService.targetOf(2, 3), 0);
  });
}
