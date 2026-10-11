import 'dart:io';
import 'dart:typed_data';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Galería en memoria: los ids que siguen en ella.
class FakeGallery extends VideoGallery {
  FakeGallery({Set<String>? ids, this.mode = GalleryAccess.full})
    : ids = ids ?? {};

  final Set<String> ids;
  GalleryAccess mode;

  /// Falso para simular que el usuario no confirma el borrado.
  bool allowDelete = true;

  @override
  Future<GalleryAccess> access() async => mode;

  @override
  Future<String> save(String path) async {
    final id = 'v${ids.length + 1}';
    ids.add(id);
    return id;
  }

  @override
  Future<bool?> exists(String id) async => ids.contains(id);

  @override
  Future<Uint8List?> thumbnail(String id) async => null;

  @override
  Future<File?> file(String id) async => null;

  @override
  Future<bool> delete(String id) async => allowDelete && ids.remove(id);
}

/// Mis videos en memoria, sin archivos.
class MemoryVideosStore extends MyVideosStore {
  MemoryVideosStore([List<SavedVideo>? videos]) : videos = videos ?? [];

  List<SavedVideo> videos;

  @override
  Future<List<SavedVideo>> load() async => videos;

  @override
  Future<void> save(List<SavedVideo> videos) async => this.videos = videos;
}

SavedVideo video(String id, int day, {String? group = 'Los Tigres'}) =>
    SavedVideo(
      assetId: id,
      savedAt: DateTime(2026, 10, day, 21, 41),
      category: 'Animales',
      round: 2,
      points: 5,
      group: group,
      groups: const ['Los Tigres', 'Las Águilas'],
      scores: const [12, 9],
    );

ProviderContainer container(MemoryVideosStore store, FakeGallery gallery) {
  final c = ProviderContainer(
    overrides: [
      myVideosStoreProvider.overrideWithValue(store),
      videoGalleryProvider.overrideWithValue(gallery),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('el video guarda su referencia y los datos del turno', () {
    final v = video('abc', 11);
    final back = SavedVideo.fromJson(v.toJson());
    expect(back.assetId, 'abc');
    expect(back.savedAt, v.savedAt);
    expect(back.title, 'Los Tigres · +5 puntos');
    expect(back.scoreLine, 'Los Tigres 12 · Las Águilas 9');
    expect(video('x', 1, group: null).title, '+5 puntos');
  });

  test('el archivo de Mis videos se lee como se guardó', () async {
    final dir = await Directory.systemTemp.createTemp('mis_videos');
    addTearDown(() => dir.delete(recursive: true));
    final store = MyVideosStore(directory: () async => dir);
    expect(await store.load(), isEmpty);
    await store.save([video('a', 1), video('b', 2)]);
    expect((await store.load()).map((v) => v.assetId), ['a', 'b']);
  });

  test('ordena del más nuevo al más viejo y quita los que se borraron de '
      'la galería', () async {
    final store = MemoryVideosStore([
      video('a', 1),
      video('b', 3),
      video('c', 2),
    ]);
    final c = container(store, FakeGallery(ids: {'a', 'b'}));
    final data = await c.read(myVideosProvider.future);
    expect(data.videos.map((v) => v.assetId), ['b', 'a']);
    expect(store.videos.map((v) => v.assetId), isNot(contains('c')));
  });

  test('con acceso limitado no quita ninguno', () async {
    final store = MemoryVideosStore([video('a', 1), video('c', 2)]);
    final gallery = FakeGallery(ids: {'a'}, mode: GalleryAccess.limited);
    final data = await container(store, gallery).read(myVideosProvider.future);
    expect(data.videos, hasLength(2));
    expect(data.access, GalleryAccess.limited);
  });

  test(
    'agregar y borrar, solo de Mis videos o también de la galería',
    () async {
      final store = MemoryVideosStore();
      final gallery = FakeGallery(ids: {'a', 'b'});
      final c = container(store, gallery);
      final notifier = c.read(myVideosProvider.notifier);
      await notifier.add(video('a', 1));
      await notifier.add(video('b', 2));
      expect(
        (await c.read(myVideosProvider.future)).videos.map((v) => v.assetId),
        ['b', 'a'],
      );

      expect(await notifier.remove(video('a', 1), fromGallery: false), isTrue);
      expect(gallery.ids, contains('a'));

      // Si el usuario no confirma el borrado en la galería, no se quita.
      gallery.allowDelete = false;
      expect(await notifier.remove(video('b', 2), fromGallery: true), isFalse);
      expect(store.videos, hasLength(1));

      gallery.allowDelete = true;
      expect(await notifier.remove(video('b', 2), fromGallery: true), isTrue);
      expect(gallery.ids, isNot(contains('b')));
      expect((await c.read(myVideosProvider.future)).videos, isEmpty);
    },
  );
}
