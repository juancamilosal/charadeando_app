import 'package:charadeando_app/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sugiere palabras según el tiempo y las rondas', () {
    const config = GameConfig(turnDuration: Duration(seconds: 60), rounds: 3);
    expect(config.wordsPerTurn, 10);
    expect(config.wordsNeededPerGroup, 30);
  });

  test('redondea hacia arriba las palabras por turno', () {
    const config = GameConfig(turnDuration: Duration(seconds: 45), rounds: 2);
    expect(config.wordsPerTurn, 8);
    expect(config.wordsNeededPerGroup, 16);
  });

  test('calcula cuántas rondas alcanzan y el total de palabras', () {
    const config = GameConfig(
      groups: [Group('A'), Group('B'), Group('C')],
      turnDuration: Duration(seconds: 60),
      rounds: 3,
      wordsPerGroup: 15,
    );
    expect(config.roundsCovered, 1);
    expect(config.totalWords, 45);
  });
}
