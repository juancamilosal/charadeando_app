import 'package:charadeando_app/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('suma las palabras de todos los grupos', () {
    const config = GameConfig(
      groups: [Group('A'), Group('B'), Group('C')],
      wordsPerGroup: 15,
    );
    expect(config.totalWords, 45);
  });

  test('permite hasta 6 grupos y empieza con 10 palabras por grupo', () {
    expect(GameConfig.maxGroups, 6);
    expect(const GameConfig().wordsPerGroup, 10);
  });
}
