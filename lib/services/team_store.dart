import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Guarda "Equipos" en un archivo del celular. No se suben a ningún
/// servidor: si se desinstala la app, se pierden.
class TeamStore {
  TeamStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const _fileName = 'equipos.json';

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  Future<List<SavedTeam>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return const [];
      return [
        for (final t in json['equipos'] as List? ?? const [])
          if (t is Map<String, dynamic>) SavedTeam.fromJson(t),
      ];
    } on Exception catch (e) {
      debugPrint('[Equipos] No se pudieron leer: $e');
      return const [];
    }
  }

  Future<void> save(List<SavedTeam> teams) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'equipos': [for (final t in teams) t.toJson()],
        }),
      );
    } on Exception catch (e) {
      debugPrint('[Equipos] No se pudieron guardar: $e');
    }
  }
}
