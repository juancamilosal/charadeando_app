import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Guarda los ajustes en un archivo del celular.
class SettingsStore {
  SettingsStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const _fileName = 'ajustes.json';

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  /// Los ajustes guardados, o los que vienen por defecto.
  Future<AppSettings> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const AppSettings();
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, dynamic>
          ? AppSettings.fromJson(json)
          : const AppSettings();
    } on Exception catch (e) {
      debugPrint('[Ajustes] No se pudieron leer: $e');
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(settings.toJson()));
    } on Exception catch (e) {
      debugPrint('[Ajustes] No se pudieron guardar: $e');
    }
  }
}
