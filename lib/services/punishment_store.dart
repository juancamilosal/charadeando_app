import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Guarda en el celular la última ruleta de castigos configurada, para
/// usarla también al final de la partida.
class PunishmentStore {
  PunishmentStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const _fileName = 'ruleta_castigos.json';

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  /// La ruleta guardada, o null si nunca se configuró.
  Future<RouletteSetup?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return null;
      final setup = RouletteSetup.fromJson(json);
      return setup.fields >= RouletteSetup.minFields ? setup : null;
    } on Exception catch (e) {
      debugPrint('[Ruleta] No se pudo leer la ruleta guardada: $e');
      return null;
    }
  }

  Future<void> save(RouletteSetup setup) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(setup.toJson()));
    } on Exception catch (e) {
      debugPrint('[Ruleta] No se pudo guardar la ruleta: $e');
    }
  }
}
