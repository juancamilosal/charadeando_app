import 'package:charadeando_app/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Word', () {
    test('cuenta todas las palabras, incluidos artículos y conectores', () {
      expect(Word('El Rey León').wordCount, 3);
      expect(Word('Estoy corriendo').wordCount, 2);
    });

    test('normaliza espacios', () {
      final word = Word('  Harry   Potter ');
      expect(word.text, 'Harry Potter');
      expect(word.wordCount, 2);
    });
  });

  group('Turn.points', () {
    final turn = Turn(
      round: 1,
      groupIndex: 0,
      entries: [
        TurnEntry(Word('Estoy corriendo'), WordOutcome.hit),
        TurnEntry(Word('El Rey León'), WordOutcome.hit),
        TurnEntry(Word('Colombia'), WordOutcome.pass),
      ],
    );

    test('por palabra suma un punto por palabra y pasar no cuenta', () {
      expect(turn.points(ScoringMode.perWord), 5);
    });

    test('por frase suma un punto por frase y pasar no cuenta', () {
      expect(turn.points(ScoringMode.perPhrase), 2);
    });

    test('separa aciertos y pases', () {
      expect(turn.hits.map((w) => w.text), ['Estoy corriendo', 'El Rey León']);
      expect(turn.passed.map((w) => w.text), ['Colombia']);
    });
  });
}
