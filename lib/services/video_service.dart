import 'dart:io';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Maneja los videos temporales de los turnos. Los videos viven en una
/// carpeta temporal de la app y solo salen de ella si el usuario los guarda
/// en la galería o los comparte.
class VideoService {
  static const _folder = 'charadeando_videos';

  /// Carpeta temporal donde viven los videos de la partida.
  Future<Directory> directory() async {
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/$_folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Mueve el video recién grabado a la carpeta temporal de la app y
  /// devuelve su nueva ruta.
  Future<String> keep(XFile recorded) async {
    final dir = await directory();
    final target =
        '${dir.path}/turno_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final source = File(recorded.path);
    try {
      await source.rename(target);
    } on FileSystemException {
      await source.copy(target);
      await source.delete();
    }
    return target;
  }

  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Borra todos los videos temporales, por ejemplo los que quedaron de una
  /// partida que se cerró a la mitad.
  Future<void> deleteAll() async {
    final dir = await directory();
    await for (final entity in dir.list()) {
      await entity.delete(recursive: true);
    }
  }

  /// Guarda una copia en la galería del celular. Lanza [GalException] si el
  /// usuario niega el permiso.
  Future<void> saveToGallery(String path) async {
    if (!await Gal.hasAccess()) {
      await Gal.requestAccess();
    }
    await Gal.putVideo(path);
  }

  Future<void> share(String path) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path, mimeType: 'video/mp4')]),
    );
  }
}
