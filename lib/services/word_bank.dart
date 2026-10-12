import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'directus_service.dart';
import 'mix_words.dart';

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

  /// Trae [count] palabras nuevas de [category] (o de varias
  /// [categories], repartidas en partes iguales) y [difficulty] (códigos de
  /// Directus). Sin internet usa el último lote guardado de esas mismas
  /// categorías y dificultad; si no hay, lanza el error de Directus.
  Future<WordBatch> load(
    int count, {
    String? category,
    List<String>? categories,
    String? difficulty,
  }) async {
    final stored = await _read();
    final which = categories != null
        ? ([...categories]..sort()).join('+')
        : category ?? '';
    final cacheKey = '$which/${difficulty ?? ''}';
    final List<RemoteWord> fetched;
    try {
      fetched = categories == null
          ? await _directus.fetchWords(
              count: count,
              category: category,
              difficulty: difficulty,
              exclude: stored.history,
            )
          : await _fetchMix(count, categories, difficulty, stored.history);
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

  /// Palabras de varias categorías en un solo pedido. Si llegan palabras de
  /// otras categorías, el servidor no sabe repartirlas (la extensión no
  /// está actualizada): se descartan y se pide cada categoría por separado,
  /// en partes iguales.
  Future<List<RemoteWord>> _fetchMix(
    int count,
    List<String> categories,
    String? difficulty,
    List<String> exclude,
  ) async {
    final wanted = categories.toSet();
    final all = await _directus.fetchWords(
      count: count,
      categories: categories,
      difficulty: difficulty,
      exclude: exclude,
    );
    final ours = [
      for (final w in all)
        if (wanted.contains(w.categoria)) w,
    ];
    if (ours.length == all.length) return ours;
    debugPrint(
      '[WordBank] El servidor no repartió por categorías: se pide cada una.',
    );
    final quotas = MixWords.quotas(count, categories.length);
    return [
      for (var i = 0; i < categories.length; i++)
        if (quotas[i] > 0)
          for (final w in await _directus.fetchWords(
            count: quotas[i],
            category: categories[i],
            difficulty: difficulty,
            exclude: exclude,
          ))
            if (w.categoria == categories[i]) w,
    ];
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

  /// Categoría y dificultad del último lote ("ANIMALES/FACIL", o
  /// "ANIMALES+PELICULAS/FACIL" en una mezcla), para no jugar sin internet
  /// con palabras de otras categorías.
  final String cacheKey;
}
