import 'dart:math';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nombra cada grupo con un nombre distinto', () {
    for (final groups in [2, 4, 6]) {
      final result = AutoFill.pick(
        const GameConfig(),
        groups: groups,
        random: Random(groups),
      );
      expect(result.names, hasLength(groups));
      expect(result.names.toSet(), hasLength(groups));
      expect(result.config.groups.map((g) => g.name), result.names);
    }
  });

  test('al volver a llenar no repite los nombres de antes', () {
    final first = AutoFill.pick(const GameConfig(), groups: 6);
    final second = AutoFill.pick(
      first.config,
      groups: 6,
      previousNames: first.names,
    );
    expect(second.names.any(first.names.contains), isFalse);
  });

  test('las palabras automáticas alcanzan para los grupos y respetan los '
      'límites', () {
    final random = Random(9);
    for (var i = 0; i < 200; i++) {
      final groups = 2 + i % 5;
      final result = AutoFill.pick(
        const GameConfig(wordSource: WordSource.random),
        groups: groups,
        random: random,
      );
      final words = result.config.autoWordCount;
      expect(words % 5, 0);
      expect(
        words,
        inInclusiveRange(GameConfig.minAutoWords, GameConfig.maxAutoWords),
      );
      expect(words / groups, inInclusiveRange(5, 16));
      expect(result.config.rounds, inInclusiveRange(2, 4));
      expect(result.config.wordsPerGroup, inInclusiveRange(5, 10));
      expect(
        AutoFill.turnSeconds,
        contains(result.config.turnDuration.inSeconds),
      );
      expect(result.hitMode.available, isTrue);
    }
  });

  test('conserva la categoría, el origen de las palabras y el video', () {
    const current = GameConfig(
      wordSource: WordSource.random,
      category: GameCategory.animals,
      resolution: VideoResolution.off,
    );
    final result = AutoFill.pick(current, groups: 2, random: Random(1));
    expect(result.config.category, GameCategory.animals);
    expect(result.config.wordSource, WordSource.random);
    expect(result.config.resolution, VideoResolution.off);
  });

  test('cada vez elige distinto', () {
    final random = Random(5);
    final picks = {
      for (var i = 0; i < 30; i++)
        AutoFill.pick(
          const GameConfig(wordSource: WordSource.random),
          groups: 2,
          random: random,
        ).gameEnd,
    };
    expect(picks, hasLength(GameEnd.values.length));
  });
}
