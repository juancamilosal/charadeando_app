import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Recuerda en el celular si ya se vio la bienvenida, para mostrarla solo
/// la primera vez que se abre la app. Se pierde si se desinstala la app.
class WelcomeStore {
  WelcomeStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const _fileName = 'bienvenida_vista';

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  /// Si ya se tocó "Listo" alguna vez. Si no se puede leer, se muestra.
  Future<bool> seen() async {
    try {
      return await (await _file()).exists();
    } on Exception catch (e) {
      debugPrint('[Bienvenida] No se pudo leer si ya se vio: $e');
      return false;
    }
  }

  Future<void> markSeen() async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString('1');
    } on Exception catch (e) {
      debugPrint('[Bienvenida] No se pudo guardar: $e');
    }
  }
}
