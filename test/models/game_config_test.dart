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

  test('jugar sin grabar no abre la cámara', () {
    expect(VideoResolution.off.records, isFalse);
    expect(VideoResolution.off.preset, isNull);
    expect(VideoResolution.hd.records, isTrue);
    expect(const GameConfig().resolution, VideoResolution.hd);
  });

  test('el Modo TV no está entre las opciones de aciertos', () {
    expect(HitMode.selectable, isNot(contains(HitMode.tv)));
    expect(HitMode.selectable, contains(HitMode.tilt));
  });

  test('el Modo TV no graba video', () {
    const tv = GameConfig(hitMode: HitMode.tv);
    expect(tv.tvMode, isTrue);
    expect(tv.resolution.records, isTrue);
    expect(tv.records, isFalse);
    expect(const GameConfig().records, isTrue);
    expect(
      const GameConfig(
        hitMode: HitMode.tv,
        wordSource: WordSource.random,
      ).tvMode,
      isTrue,
    );
  });
}
