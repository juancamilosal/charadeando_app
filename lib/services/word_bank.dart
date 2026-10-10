import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'directus_service.dart';
import 'gemini_service.dart';

/// Palabras descargadas para una partida automática.
class WordBatch {
  const WordBatch(this.words, {required this.offline});

  final List<Word> words;

  /// Verdadero si no hubo internet y se usaron las últimas palabras
  /// descargadas, que pueden repetirse.
  final bool offline;
}

/// Descarga las palabras automáticas:
///
/// 1. Se las pide a Gemini (flujo de Directus).
/// 2. Si Gemini falla, o repite palabras jugadas hace poco, completa con la
///    colección de palabras de Directus (`/juego/palabras`).
/// 3. Sin internet, usa el último lote guardado.
///
/// En el celular guarda las últimas palabras jugadas, para no repetirlas
/// entre partidas, y el último lote. Nada de esto sale del celular salvo los
/// ids que se piden excluir a Directus.
class WordBank {
  WordBank(
    this._gemini,
    this._directus, {
    Future<Directory> Function()? directory,
    Random? random,
  }) : _directory = directory ?? getApplicationSupportDirectory,
       _random = random ?? Random();

  static const _fileName = 'palabras_automaticas.json';

  /// Cuántos ids de palabras jugadas se recuerdan.
  static const historySize = DirectusService.maxExclude;

  final GeminiService _gemini;
  final DirectusService _directus;
  final Future<Directory> Function() _directory;
  final Random _random;

  /// Trae [count] palabras nuevas. Sin internet usa el último lote guardado;
  /// si tampoco hay lote, lanza el error de Directus.
  Future<WordBatch> load(int count, {String? category}) async {
    final stored = await _read();
    final recent = stored.texts.toSet();

    var fromGemini = const <String>[];
    try {
      fromGemini = await _gemini.fetchWords(count);
    } on GeminiException catch (e) {
      debugPrint('[WordBank] Gemini falló, se usa Directus: $e');
    }
    final fresh = [
      for (final t in fromGemini)
        if (!recent.contains(_key(t))) t,
    ];
    final repeated = [
      for (final t in fromGemini)
        if (recent.contains(_key(t))) t,
    ];
    final words = [
      for (final t in fresh.take(count))
        RemoteWord(id: '', frase: t, categoria: ''),
    ];

    final missing = count - words.length;
    if (missing > 0) {
      try {
        final taken = {for (final w in words) _key(w.frase)};
        final extra = await _directus.fetchWords(
          count: missing,
          category: category,
          exclude: stored.history,
        );
        words.addAll(extra.where((w) => taken.add(_key(w.frase))));
      } on DirectusException catch (e) {
        if (words.isEmpty && repeated.isEmpty) {
          if (stored.cache.isEmpty) rethrow;
          debugPrint('[WordBank] Sin conexión, se usa el último lote: $e');
          final cache = [...stored.cache]..shuffle(_random);
          return WordBatch([
            for (final w in cache.take(count)) w.toWord(),
          ], offline: true);
        }
        debugPrint('[WordBank] Directus falló, se completa con Gemini: $e');
      }
      // Si aún faltan, mejor repetir alguna de Gemini que quedarse corto.
      for (final t in repeated) {
        if (words.length >= count) break;
        words.add(RemoteWord(id: '', frase: t, categoria: ''));
      }
    }

    await _write(
      _Stored(
        history: _remember(stored.history, [
          for (final w in words)
            if (w.id.isNotEmpty) w.id,
        ]),
        texts: _remember(stored.texts, [for (final w in words) _key(w.frase)]),
        cache: words,
      ),
    );
    return WordBatch([for (final w in words) w.toWord()], offline: false);
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
        texts: [for (final t in (json['textos'] as List?) ?? const []) '$t'],
        cache: [
          for (final w in json['lote'] as List)
            RemoteWord.fromJson(w as Map<String, dynamic>),
        ],
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
          'textos': stored.texts,
          'lote': [for (final w in stored.cache) w.toJson()],
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
    this.texts = const [],
    this.cache = const [],
  });

  /// Ids de Directus de las últimas palabras jugadas.
  final List<String> history;

  /// Las mismas palabras en texto, para reconocer las que repite Gemini.
  final List<String> texts;
  final List<RemoteWord> cache;
}
