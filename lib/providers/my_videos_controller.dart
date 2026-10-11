import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'providers.dart';

/// Lo que muestra "Mis videos".
class MyVideosData {
  const MyVideosData({
    this.videos = const [],
    this.access = GalleryAccess.full,
  });

  /// Del más nuevo al más viejo.
  final List<SavedVideo> videos;

  /// Con acceso limitado (iPhone) algunos videos pueden no verse aunque
  /// sigan en la galería.
  final GalleryAccess access;
}

/// "Mis videos": los videos guardados en la galería desde la app.
class MyVideosController extends AsyncNotifier<MyVideosData> {
  MyVideosStore get _store => ref.read(myVideosStoreProvider);
  VideoGallery get _gallery => ref.read(videoGalleryProvider);

  /// Al abrir la sección se quitan los videos que ya se borraron de la
  /// galería. Con acceso limitado o sin permiso no se quita ninguno: no se
  /// puede saber si siguen ahí.
  @override
  Future<MyVideosData> build() async {
    final saved = await _store.load();
    final access = await _gallery.access();
    var videos = saved;
    if (access == GalleryAccess.full) {
      videos = [
        for (final v in saved)
          if (await _gallery.exists(v.assetId) != false) v,
      ];
      if (videos.length != saved.length) await _store.save(videos);
    }
    return MyVideosData(videos: _sorted(videos), access: access);
  }

  /// Agrega un video recién guardado en la galería. La lista se vuelve a
  /// leer, por si se estaba cargando.
  Future<void> add(SavedVideo video) async {
    final saved = await _store.load();
    await _store.save([video, ...saved.where((v) => v != video)]);
    ref.invalidateSelf();
  }

  /// Quita el video de Mis videos y, si [fromGallery], también de la
  /// galería. Devuelve falso si no se pudo borrar de la galería (por
  /// ejemplo, el usuario no lo confirmó); entonces no se quita.
  Future<bool> remove(SavedVideo video, {required bool fromGallery}) async {
    if (fromGallery && !await _gallery.delete(video.assetId)) return false;
    final videos = [
      for (final v in await _store.load())
        if (v != video) v,
    ];
    await _store.save(videos);
    final access = state.value?.access ?? GalleryAccess.full;
    state = AsyncData(MyVideosData(videos: _sorted(videos), access: access));
    return true;
  }

  static List<SavedVideo> _sorted(List<SavedVideo> videos) =>
      [...videos]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
}
