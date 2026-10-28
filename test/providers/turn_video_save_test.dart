import 'dart:async';
import 'dart:io';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../services/settings_test.dart' show MemorySettingsStore;
import 'my_videos_test.dart' show FakeGallery, MemoryVideosStore;

/// Videos en una carpeta temporal de verdad.
class _TempVideos extends VideoService {
  _TempVideos(this.dir);

  final Directory dir;

  @override
  Future<Directory> directory() async => dir;
}

/// Arma el video cuando se le dice ([finish]).
class _SlowRenderer extends VideoRenderer {
  final done = Completer<void>();

  void finish() => done.complete();

  @override
  Future<String> render(
    TurnRecording recording, {
    required Directory workDir,
    required String outputPath,
    required int bitrateMbps,
    bool watermark = false,
    void Function(double progress)? onProgress,
  }) async {
    await done.future;
    File(outputPath).writeAsStringSync('video');
    return outputPath;
  }

  @override
  Future<void> cancel() async {}
}

void main() {
  late Directory dir;
  late FakeGallery gallery;
  late MemoryVideosStore store;
  late _SlowRenderer renderer;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('videos');
    gallery = FakeGallery();
    store = MemoryVideosStore();
    renderer = _SlowRenderer();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  ProviderContainer container({required bool autoSave}) {
    final c = ProviderContainer(
      overrides: [
        videoServiceProvider.overrideWithValue(_TempVideos(dir)),
        videoRendererProvider.overrideWithValue(renderer),
        videoGalleryProvider.overrideWithValue(gallery),
        myVideosStoreProvider.overrideWithValue(store),
        settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        settingsProvider.overrideWith(
          () => SettingsController(AppSettings(autoSaveVideo: autoSave)),
        ),
        premiumUnlockedProvider.overrideWithValue(true),
      ],
    );
    addTearDown(c.dispose);
    final game = c.read(gameControllerProvider.notifier);
    game.configure(const GameConfig(category: GameCategory.animals));
    game.startWithDecks([
      [Word('León')],
      [Word('Jirafa')],
    ]);
    game.finishTurn(
      Turn(
        round: 1,
        groupIndex: 0,
        entries: [TurnEntry(Word('León'), WordOutcome.hit)],
      ),
    );
    return c;
  }

  TurnRecording recording() {
    final segment = File('${dir.path}/turno_1.mp4')..writeAsStringSync('x');
    return TurnRecording(
      segments: [segment.path],
      captions: const [],
      duration: const Duration(seconds: 60),
    );
  }

  test('"Guardar" lleva el video a la galería y a Mis videos', () async {
    final c = container(autoSave: false);
    final controller = c.read(turnVideoProvider.notifier);
    final processing = controller.process(recording(), VideoResolution.hd);
    renderer.finish();
    await processing;
    expect(c.read(turnVideoProvider).unsaved, isTrue);
    expect(store.videos, isEmpty);

    expect(
      await controller.save(),
      'Video guardado en la galería y en Mis videos.',
    );
    expect(c.read(turnVideoProvider).saved, isTrue);
    expect(gallery.ids, hasLength(1));
    expect(store.videos.single.category, 'Animales');
    expect(store.videos.single.group, isNotNull);
  });

  test(
    'con "Guardar automáticamente" se guarda solo al terminar de armarse',
    () async {
      final c = container(autoSave: true);
      final processing = c
          .read(turnVideoProvider.notifier)
          .process(recording(), VideoResolution.hd);
      renderer.finish();
      await processing;
      expect(c.read(turnVideoProvider).saved, isTrue);
      expect(store.videos, hasLength(1));
    },
  );

  test('con "Guardar automáticamente" se guarda aunque salgan del resultado '
      'antes de que termine de armarse', () async {
    final c = container(autoSave: true);
    final controller = c.read(turnVideoProvider.notifier);
    final processing = controller.process(recording(), VideoResolution.hd);
    await Future<void>.delayed(Duration.zero);
    // Salen del resultado mientras se arma.
    await controller.discard();
    expect(c.read(turnVideoProvider).status, TurnVideoStatus.none);
    renderer.finish();
    await processing;
    expect(store.videos, hasLength(1));
    expect(gallery.ids, hasLength(1));
    // El archivo temporal se borra después de guardarlo.
    expect(dir.listSync(), isEmpty);
  });
}
