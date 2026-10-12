import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// La última combinación de "Combinar categorías": los códigos de las
/// categorías del juego y los ids de las propias.
class SavedMix {
  const SavedMix({this.categories = const [], this.custom = const []});

  final List<String> categories;
  final List<String> custom;
}

/// Recuerda en el celular la última combinación elegida.
class MixStore {
  MixStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const _fileName = 'combinacion.json';

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  Future<SavedMix> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const SavedMix();
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return const SavedMix();
      List<String> strings(Object? list) => [
        for (final v in list is List ? list : const [])
          if (v is String) v,
      ];
      return SavedMix(
        categories: strings(json['juego']),
        custom: strings(json['mias']),
      );
    } on Exception catch (e) {
      debugPrint('[Combinar] No se pudo leer la combinación: $e');
      return const SavedMix();
    }
  }

  Future<void> save(SavedMix mix) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({'juego': mix.categories, 'mias': mix.custom}),
      );
    } on Exception catch (e) {
      debugPrint('[Combinar] No se pudo guardar la combinación: $e');
    }
  }
}
