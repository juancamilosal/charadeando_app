import 'dart:io';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guarda la última configuración y la recupera', () async {
    final dir = await Directory.systemTemp.createTemp('configuracion');
    addTearDown(() => dir.delete(recursive: true));
    final store = ConfigStore(directory: () async => dir);
    expect(await store.load(), isNull);

    await store.save(
      const SavedConfig(
        groupNames: ['Los Tigres', 'Las Águilas', 'Los Lobos'],
        rounds: 5,
        turnDuration: Duration(seconds: 75),
        wordsPerGroup: 8,
        scoringMode: ScoringMode.perWord,
        hitMode: HitMode.tilt,
        resolution: VideoResolution.off,
        difficulty: Difficulty.easy,
      ),
    );
    final loaded = (await store.load())!;
    expect(loaded.groupNames, ['Los Tigres', 'Las Águilas', 'Los Lobos']);
    expect(loaded.rounds, 5);
    expect(loaded.turnDuration, const Duration(seconds: 75));
    expect(loaded.wordsPerGroup, 8);
    expect(loaded.scoringMode, ScoringMode.perWord);
    expect(loaded.resolution, VideoResolution.off);
    expect(loaded.difficulty, Difficulty.easy);
  });

  test('el Modo TV no se guarda: vuelve a Movimiento', () {
    final loaded = SavedConfig.fromJson({'aciertos': 'tv'});
    expect(loaded.hitMode, HitMode.tilt);
    expect(loaded.scoringMode, ScoringMode.perPhrase);
  });
}
