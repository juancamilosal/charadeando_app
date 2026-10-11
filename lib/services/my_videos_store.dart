import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Guarda la lista de "Mis videos" en un archivo del celular: solo la
/// referencia a cada video de la galería y los datos del turno. Los videos
/// nunca se suben a ningún servidor.
class MyVideosStore {
  MyVideosStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const _fileName = 'mis_videos.json';

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  Future<List<SavedVideo>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final json = jsonDecode(await file.readAsString());
      return [
        for (final v in json is List ? json : const [])
          if (v is Map<String, dynamic> && v['id'] is String)
            SavedVideo.fromJson(v),
      ];
    } on Exception catch (e) {
      debugPrint('[Mis videos] No se pudo leer el archivo: $e');
      return const [];
    }
  }

  Future<void> save(List<SavedVideo> videos) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode([for (final v in videos) v.toJson()]),
      );
    } on Exception catch (e) {
      debugPrint('[Mis videos] No se pudo guardar: $e');
    }
  }
}
