import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

/// Qué tanto puede ver la app de la galería.
enum GalleryAccess {
  /// Todo, o en Android los videos que guardó la propia app.
  full,

  /// En iPhone, solo las fotos y videos que el usuario eligió. Los que no
  /// eligió no se ven, aunque sigan en la galería.
  limited,

  /// Sin permiso.
  denied,
}

/// No se pudo guardar el video en la galería.
class GalleryException implements Exception {
  const GalleryException(this.denied);

  /// Verdadero si el usuario no dio permiso.
  final bool denied;

  @override
  String toString() => denied
      ? 'Sin permiso para guardar en la galería'
      : 'No se pudo guardar en la galería';
}

/// Los videos de la app en la galería del celular. Mis videos guarda solo
/// su identificador: el video vive una sola vez, en la galería.
class VideoGallery {
  /// Pide permiso si hace falta. En Android 10 o más nuevo la app ve sin
  /// permiso los videos que ella misma guardó.
  Future<GalleryAccess> access() async {
    var state = PermissionState.denied;
    try {
      state = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.video,
            mediaLocation: false,
          ),
        ),
      );
    } on Exception catch (e) {
      // En Android 13 o más nuevo la app no declara el permiso de leer los
      // videos de la galería.
      debugPrint('[Mis videos] Permiso de la galería: $e');
    }
    if (state == PermissionState.limited) return GalleryAccess.limited;
    if (state.hasAccess) return GalleryAccess.full;
    if (Platform.isAndroid) {
      // Sin el permiso de leer toda la galería (que Google Play solo
      // permite a apps de galería), la app sigue viendo lo que guardó.
      PhotoManager.setIgnorePermissionCheck(true);
      return GalleryAccess.full;
    }
    return GalleryAccess.denied;
  }

  /// En iPhone con acceso limitado, deja elegir qué fotos y videos ve la
  /// app.
  Future<void> manageLimitedAccess() =>
      PhotoManager.presentLimited(type: RequestType.video);

  /// Abre los ajustes de la app para dar el permiso.
  Future<void> openSettings() => PhotoManager.openSetting();

  /// Guarda el video en la galería y devuelve su identificador.
  Future<String> save(String path) async {
    final access = await this.access();
    if (access == GalleryAccess.denied) throw const GalleryException(true);
    try {
      final asset = await PhotoManager.editor.saveVideo(
        File(path),
        title: path.split('/').last,
        relativePath: Platform.isAndroid ? 'Movies/Charadeando' : null,
      );
      return asset.id;
    } on Exception catch (e) {
      debugPrint('[Mis videos] No se pudo guardar en la galería: $e');
      throw const GalleryException(false);
    }
  }

  /// Si el video sigue en la galería. Null si no se puede saber.
  Future<bool?> exists(String id) async {
    try {
      return await AssetEntity.fromId(id) != null;
    } on Exception catch (e) {
      debugPrint('[Mis videos] No se pudo revisar el video: $e');
      return null;
    }
  }

  Future<Uint8List?> thumbnail(String id) async {
    try {
      final asset = await AssetEntity.fromId(id);
      return await asset?.thumbnailDataWithSize(const ThumbnailSize(320, 180));
    } on Exception {
      return null;
    }
  }

  /// El archivo del video, para verlo o compartirlo. Null si ya no está.
  Future<File?> file(String id) async {
    try {
      return await (await AssetEntity.fromId(id))?.file;
    } on Exception {
      return null;
    }
  }

  /// Borra el video de la galería. El celular puede pedir confirmación.
  /// Devuelve falso si no se borró.
  Future<bool> delete(String id) async {
    try {
      final deleted = await PhotoManager.editor.deleteWithIds([id]);
      return deleted.contains(id);
    } on Exception catch (e) {
      debugPrint('[Mis videos] No se pudo borrar de la galería: $e');
      return false;
    }
  }
}
