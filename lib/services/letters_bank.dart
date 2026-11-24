import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'directus_service.dart';

/// No se pudieron traer las temáticas de Letras. [offline] si fue por
/// falta de internet.
class LettersException implements Exception {
  const LettersException(this.message, {this.offline = false});

  final String message;
  final bool offline;

  static const noConnection = LettersException(
    'La Bomba necesita internet para descargar las temáticas. Revisa tu '
    'conexión e inténtalo otra vez.',
    offline: true,
  );

  static const empty = LettersException(
    'Todavía no hay temáticas para jugar La Bomba. Inténtalo más tarde.',
  );

  @override
  String toString() => 'LettersException($message)';
}

/// Las temáticas del juego Letras: las pide a Directus (`/juego/tematicas`)
/// y recuerda en el celular las que ya salieron ([remember]), para no
/// repetirlas en las partidas siguientes.
class LettersBank {
  LettersBank(this._directus, {Future<Directory> Function()? historyDirectory})
    : _historyDirectory = historyDirectory ?? getApplicationSupportDirectory;

  static const _historyFile = 'tematicas_vistas.json';

  /// Cuántos ids de temáticas jugadas se recuerdan.
  static const historySize = DirectusService.maxExclude;

  /// Temáticas que se piden al abrir el juego (alcanzan para muchas bombas).
  static const perGame = 100;

  /// Por ahora Letras es gratis y completo: salen todas las temáticas
  /// (también las marcadas `premium` en Directus).
  static const freeForNow = true;

  final DirectusService _directus;
  final Future<Directory> Function() _historyDirectory;

  /// Temáticas para jugar, primero las que no han salido, en orden al
  /// azar. Lanza [LettersException] sin internet o si no hay ninguna.
  Future<List<LettersTopic>> prepare({required bool includePremium}) async {
    final history = await _readHistory();
    final List<LettersTopic> fetched;
    try {
      fetched = await _directus.fetchTopics(
        count: perGame,
        exclude: history,
        includePremium: includePremium,
      );
    } on DirectusException catch (e) {
      if (e.statusCode == null) throw LettersException.noConnection;
      rethrow;
    }
    final seen = <String>{};
    final topics = [
      for (final t in fetched)
        if (seen.add(t.id)) t,
    ];
    if (topics.isEmpty) throw LettersException.empty;
    return topics..shuffle();
  }

  /// Anota [topic] como jugada.
  Future<void> remember(LettersTopic topic) async {
    if (topic.id.isEmpty) return;
    final history = await _readHistory();
    final ids = [
      for (final id in history)
        if (id != topic.id) id,
      topic.id,
    ];
    await _writeHistory(
      ids.sublist(ids.length > historySize ? ids.length - historySize : 0),
    );
  }

  @visibleForTesting
  Future<List<String>> history() => _readHistory();

  Future<File> _history() async =>
      File('${(await _historyDirectory()).path}/$_historyFile');

  Future<List<String>> _readHistory() async {
    try {
      final file = await _history();
      if (!await file.exists()) return const [];
      final json = jsonDecode(await file.readAsString());
      return [for (final id in json['vistas'] as List) '$id'];
    } catch (e) {
      debugPrint('[Letras] No se pudo leer el historial: $e');
      return const [];
    }
  }

  Future<void> _writeHistory(List<String> ids) async {
    try {
      final file = await _history();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({'vistas': ids}));
    } catch (e) {
      debugPrint('[Letras] No se pudo guardar el historial: $e');
    }
  }
}
