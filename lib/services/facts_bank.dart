import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'directus_service.dart';

/// No se pudo preparar ¿Más o menos?. [offline] si fue por falta de
/// internet.
class FactsException implements Exception {
  const FactsException(this.message, {this.offline = false});

  final String message;
  final bool offline;

  static const noConnection = FactsException(
    '¿Más o menos? necesita internet para descargar los datos. Revisa tu '
    'conexión e inténtalo otra vez.',
    offline: true,
  );

  static const notEnough = FactsException(
    'Todavía no hay suficientes datos para jugar ¿Más o menos?. '
    'Inténtalo más tarde.',
  );

  @override
  String toString() => 'FactsException($message)';
}

/// Prepara los datos de una partida de ¿Más o menos?: los pide a Directus
/// (`/juego/datos`). Sin internet no se puede jugar.
///
/// Recuerda en el celular los ids de los datos que ya salieron en un
/// turno ([remember]), para no repetirlos en las partidas siguientes.
class FactsBank {
  FactsBank(this._directus, {Future<Directory> Function()? historyDirectory})
    : _historyDirectory = historyDirectory ?? getApplicationSupportDirectory;

  static const _historyFile = 'datos_vistos.json';

  /// Cuántos ids de datos jugados se recuerdan.
  static const historySize = DirectusService.maxExclude;

  /// Datos que se preparan como mucho por partida. Si se acaban durante el
  /// juego, vuelven los ya jugados.
  static const maxPerGame = DirectusService.maxFacts;

  /// Por ahora ¿Más o menos? es gratis y completo: salen todos los datos
  /// (también los marcados `premium` en Directus). Más adelante será
  /// Premium.
  static const freeForNow = true;

  final DirectusService _directus;
  final Future<Directory> Function() _historyDirectory;

  /// Datos para la partida: hasta [count] (como mucho [maxPerGame]), de
  /// [difficulty] (null o Mezclada, de todas), en orden al azar. Con
  /// [includePremium] también salen los de Premium. Lanza [FactsException]
  /// sin internet o si no llegan al menos [minimum].
  Future<List<Word>> prepare(
    int count, {
    Difficulty? difficulty,
    required bool includePremium,
    int minimum = 1,
  }) async {
    final history = await _readHistory();
    final List<FactItem> fetched;
    try {
      fetched = await _directus.fetchFacts(
        count: count.clamp(1, maxPerGame),
        difficulty: difficulty?.code,
        exclude: history,
        includePremium: includePremium,
      );
    } on DirectusException catch (e) {
      if (e.statusCode == null) throw FactsException.noConnection;
      rethrow;
    }
    final seen = <String>{};
    final words = [
      for (final f in fetched)
        if (seen.add(f.id)) wordOf(f),
    ];
    if (words.length < minimum) throw FactsException.notEnough;
    return words..shuffle();
  }

  /// El dato como [Word]: la pregunta es el texto.
  static Word wordOf(FactItem fact) => Word(
    fact.question,
    category: GameCategory.moreOrLess.code,
    id: fact.id,
    answer: fact.answerText,
    topic: fact.topic,
    note: fact.note,
  );

  /// Anota como jugados los datos de [words] (los que salieron en un
  /// turno).
  Future<void> remember(Iterable<Word> words) async {
    final ids = [
      for (final w in words)
        if (w.isFact && w.id != null) w.id!,
    ];
    if (ids.isEmpty) return;
    await _writeHistory(_merge(await _readHistory(), ids));
  }

  /// Los ids ya jugados, del más viejo al más reciente.
  @visibleForTesting
  Future<List<String>> history() => _readHistory();

  List<String> _merge(List<String> history, List<String> added) {
    final unique = <String>[];
    final seen = <String>{};
    for (final id in [...history, ...added].reversed) {
      if (seen.add(id)) unique.add(id);
    }
    return unique.take(historySize).toList().reversed.toList();
  }

  Future<File> _history() async =>
      File('${(await _historyDirectory()).path}/$_historyFile');

  Future<List<String>> _readHistory() async {
    try {
      final file = await _history();
      if (!await file.exists()) return const [];
      final json = jsonDecode(await file.readAsString());
      return [for (final id in json['vistos'] as List) '$id'];
    } catch (e) {
      // Un archivo dañado no debe impedir jugar.
      debugPrint('[¿Más o menos?] No se pudo leer el historial: $e');
      return const [];
    }
  }

  Future<void> _writeHistory(List<String> ids) async {
    try {
      final file = await _history();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({'vistos': ids}));
    } catch (e) {
      debugPrint('[¿Más o menos?] No se pudo guardar el historial: $e');
    }
  }
}
