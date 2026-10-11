import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/screens/auto_words_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('suma las palabras de todos los grupos', () {
    const config = GameConfig(
      groups: [Group('A'), Group('B'), Group('C')],
      wordsPerGroup: 15,
    );
    expect(config.totalWords, 45);
  });

  test('permite hasta 4 grupos, turnos de 1:30 y empieza con 10 palabras '
      'por grupo', () {
    expect(GameConfig.maxGroups, 4);
    expect(GameConfig.maxTurnSeconds, 90);
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

  test('se piden las palabras que alcanzaría un grupo rápido en todos los '
      'turnos', () {
    const config = GameConfig(wordSource: WordSource.random, rounds: 3);
    // 20 por turno (una cada 3 s) × 2 grupos × 3 rondas.
    expect(AutoWordsScreen.countFor(config), 120);
    // Nunca más que el tope del servidor.
    expect(
      AutoWordsScreen.countFor(
        config.copyWith(
          rounds: 10,
          turnDuration: const Duration(seconds: 90),
          groups: List.filled(4, const Group('G')),
        ),
      ),
      DirectusService.maxCount,
    );
  });

  test('mezcladas trae de todas las dificultades', () {
    expect(Difficulty.mixed.code, isNull);
    expect(Difficulty.values.first, Difficulty.mixed);
  });
}
