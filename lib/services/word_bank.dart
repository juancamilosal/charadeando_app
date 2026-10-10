import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'directus_service.dart';

/// Palabras descargadas para una partida automática.
class WordBatch {
  const WordBatch(this.words, {required this.offline});

  final List<Word> words;

  /// Verdadero si no hubo internet y se usaron las últimas palabras
  /// descargadas, que pueden repetirse.
  final bool offline;
}

/// Descarga las palabras automáticas de la colección de Directus
/// (`/juego/palabras`). Sin internet, usa el último lote guardado.
///
/// En el celular guarda las últimas palabras jugadas, para no repetirlas
/// entre partidas, y el último lote. Nada de esto sale del celular salvo los
/// ids que se piden excluir a Directus.
class WordBank {
  WordBank(
    this._directus, {
    Future<Directory> Function()? directory,
    Random? random,
  }) : _directory = directory ?? getApplicationSupportDirectory,
       _random = random ?? Random();

  static const _fileName = 'palabras_automaticas.json';

  /// Cuántos ids de palabras jugadas se recuerdan.
  static const historySize = DirectusService.maxExclude;

  final DirectusService _directus;
  final Future<Directory> Function() _directory;
  final Random _random;

  /// Trae [count] palabras nuevas de [category] y [difficulty] (códigos de
  /// Directus). Sin internet usa el último lote guardado de esa misma
  /// categoría y dificultad; si no hay, lanza el error de Directus.
  Future<WordBatch> load(
    int count, {
    String? category,
    String? difficulty,
  }) async {
    final stored = await _read();
    final cacheKey = '${category ?? ''}/${difficulty ?? ''}';
    final List<RemoteWord> fetched;
    try {
      fetched = await _directus.fetchWords(
        count: count,
        category: category,
        difficulty: difficulty,
        exclude: stored.history,
      );
    } on DirectusException catch (e) {
      if (stored.cache.isEmpty || stored.cacheKey != cacheKey) rethrow;
      debugPrint('[WordBank] Sin conexión, se usa el último lote: $e');
      final cache = [...stored.cache]..shuffle(_random);
      return WordBatch([
        for (final w in cache.take(count)) w.toWord(),
      ], offline: true);
    }
    // Por si la colección tiene la misma frase dos veces.
    final taken = <String>{};
    final words = fetched.where((w) => taken.add(_key(w.frase))).take(count);

    final batch = words.toList();
    await _write(
      _Stored(
        history: _remember(stored.history, [
          for (final w in batch)
            if (w.id.isNotEmpty) w.id,
        ]),
        cache: batch,
        cacheKey: cacheKey,
      ),
    );
    return WordBatch([for (final w in batch) w.toWord()], offline: false);
  }

  /// Forma de comparar palabras sin importar mayúsculas ni espacios.
  static String _key(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  List<String> _remember(List<String> history, List<String> added) {
    final ids = [...history, ...added];
    // Sin duplicados, conservando el orden de la última vez que se jugaron.
    final unique = <String>[];
    final seen = <String>{};
    for (final id in ids.reversed) {
      if (seen.add(id)) unique.add(id);
    }
    return unique.take(historySize).toList().reversed.toList();
  }

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  Future<_Stored> _read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const _Stored();
      final json = jsonDecode(await file.readAsString());
      return _Stored(
        history: [for (final id in json['vistas'] as List) '$id'],
        cache: [
          for (final w in json['lote'] as List)
            RemoteWord.fromJson(w as Map<String, dynamic>),
        ],
        cacheKey: '${json['loteDe'] ?? ''}',
      );
    } catch (e) {
      // Un archivo dañado no debe impedir jugar.
      debugPrint('[WordBank] No se pudo leer el archivo local: $e');
      return const _Stored();
    }
  }

  Future<void> _write(_Stored stored) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'vistas': stored.history,
          'lote': [for (final w in stored.cache) w.toJson()],
          'loteDe': stored.cacheKey,
        }),
      );
    } catch (e) {
      debugPrint('[WordBank] No se pudo guardar el archivo local: $e');
    }
  }
}

class _Stored {
  const _Stored({
    this.history = const [],
    this.cache = const [],
    this.cacheKey = '',
  });

  /// Ids de Directus de las últimas palabras jugadas.
  final List<String> history;

  final List<RemoteWord> cache;

  /// Categoría y dificultad del último lote ("ANIMALES/FACIL"), para no
  /// jugar sin internet con palabras de otra categoría.
  final String cacheKey;
}
