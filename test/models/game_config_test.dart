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

  test('se piden las palabras de todos los turnos de la partida', () {
    const config = GameConfig(
      wordSource: WordSource.random,
      rounds: 3,
      wordsPerTurn: 12,
    );
    // 12 por turno × 2 grupos × 3 rondas.
    expect(AutoWordsScreen.countFor(config), 72);
    // Nunca más que el tope del servidor.
    expect(
      AutoWordsScreen.countFor(
        config.copyWith(
          rounds: 10,
          wordsPerTurn: 60,
          groups: List.filled(6, const Group('G')),
        ),
      ),
      DirectusService.maxCount,
    );
  });

  test('si llegan menos palabras, cada turno tiene menos', () {
    const config = GameConfig(
      wordSource: WordSource.random,
      rounds: 3,
      wordsPerTurn: 12,
    );
    expect(AutoWordsScreen.wordsPerTurnFor(config, 72), 12);
    expect(AutoWordsScreen.wordsPerTurnFor(config, 50), 8);
    expect(AutoWordsScreen.wordsPerTurnFor(config, 5), 0);
  });

  group('palabras por turno', () {
    test('el tiempo pone el máximo y sugiere una cada 5 segundos', () {
      const config = GameConfig(
        wordSource: WordSource.random,
        difficulty: Difficulty.mixed,
        rounds: 3,
      );
      expect(config.maxWordsPerTurn, 20);
      expect(config.suggestedWordsPerTurn, 12);
      expect(config.limitedByStock, isFalse);
      final long = config.copyWith(turnDuration: const Duration(seconds: 180));
      // 300 palabras mezcladas / 6 turnos = 50; el tiempo permite 60.
      expect(long.maxWordsPerTurn, 50);
      expect(long.limitedByStock, isTrue);
      expect(long.suggestedWordsPerTurn, 36);
    });

    test('con muchos grupos y rondas, la base pone el máximo', () {
      final config = GameConfig(
        wordSource: WordSource.random,
        difficulty: Difficulty.mixed,
        rounds: 10,
        groups: List.filled(6, const Group('G')),
      );
      // 300 palabras / 60 turnos.
      expect(config.maxWordsPerTurn, 5);
      expect(config.limitedByStock, isTrue);
      expect(config.suggestedWordsPerTurn, 5);
      // Una sola dificultad tiene 100: aun así hay un mínimo por turno.
      expect(
        config.copyWith(difficulty: Difficulty.easy).maxWordsPerTurn,
        GameConfig.minWordsPerTurn,
      );
    });

    test('mezcladas trae de todas las dificultades', () {
      expect(Difficulty.mixed.code, isNull);
      expect(Difficulty.mixed.stock, 3 * Difficulty.easy.stock);
    });
  });
}
