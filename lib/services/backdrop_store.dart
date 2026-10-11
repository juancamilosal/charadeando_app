import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Recuerda en el celular el fondo que eligió el usuario.
class BackdropStore {
  BackdropStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const _fileName = 'fondo.txt';

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  /// El fondo guardado, o el que viene elegido si nunca se cambió.
  Future<Backdrop> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return Backdrop.standard;
      return Backdrop.byName((await file.readAsString()).trim());
    } on Exception catch (e) {
      debugPrint('[Fondos] No se pudo leer el fondo: $e');
      return Backdrop.standard;
    }
  }

  Future<void> save(Backdrop backdrop) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(backdrop.name);
    } on Exception catch (e) {
      debugPrint('[Fondos] No se pudo guardar el fondo: $e');
    }
  }
}
