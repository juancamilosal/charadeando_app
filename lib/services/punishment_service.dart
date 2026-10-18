import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'directus_service.dart';
import 'punishments.dart';
import 'error_reporter.dart';

/// Castigos de la colección `castigos` de Directus (campo `nombre`), por
/// una ruta del juego (`POST /juego/castigos`) como la de las palabras.
class PunishmentService {
  PunishmentService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? DirectusService.defaultBaseUrl;

  static const _timeout = Duration(seconds: 15);

  /// Tope de castigos por petición. Debe coincidir con MAX_PUNISHMENTS de
  /// la extensión.
  static const maxCount = 200;

  final http.Client _client;
  final String baseUrl;

  Uri get punishmentsUri => Uri.parse('$baseUrl/juego/castigos');

  /// Trae [count] castigos al azar. Cada uno llega como
  /// `{"id": "...", "texto": "..."}`.
  Future<List<String>> fetchPunishments(int count) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            punishmentsUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'n': count}),
          )
          .timeout(_timeout);
    } on Exception catch (e, stack) {
      ErrorReporter.instance.report(e, stack, reason: 'Castigos sin respuesta');
      throw DirectusException(null, 'No se pudo conectar con el servidor: $e');
    }
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw DirectusException(response.statusCode, text);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw DirectusException(response.statusCode, 'Respuesta no válida.');
    }
    final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
    if (data is! List) {
      throw DirectusException(response.statusCode, 'Falta la lista "data".');
    }
    return [
      for (final item in data)
        if (item is Map<String, dynamic> && item['texto'] is String)
          (item['texto'] as String).trim(),
    ].where((t) => t.isNotEmpty).toList();
  }
}

/// Los castigos que la app elige para la ruleta: los de Directus, que se
/// traen una vez por sesión, o los de respaldo ([systemPunishments]) si no
/// se pudieron traer.
class PunishmentPool {
  /// Sin [fetch] (en las pruebas) se usan siempre los de respaldo.
  PunishmentPool([this._fetch]);

  final Future<List<String>> Function(int count)? _fetch;
  List<String> _current = systemPunishments;
  Future<List<String>>? _loading;

  /// Los castigos de ahora: los de respaldo hasta que lleguen los de
  /// Directus.
  List<String> get current => _current;

  /// Trae los de Directus (una sola vez; si falla, se vuelve a intentar la
  /// próxima vez) y devuelve los que quedan en [current].
  Future<List<String>> load() => _loading ??= _load();

  /// Como [load], pero sin hacer esperar más de [wait] a quien va a girar:
  /// si Directus tarda, se usan los de ahora.
  Future<List<String>> ready({Duration wait = const Duration(seconds: 3)}) =>
      load().timeout(wait, onTimeout: () => _current);

  Future<List<String>> _load() async {
    final fetch = _fetch;
    if (fetch == null) return _current;
    try {
      final seen = <String>{};
      final fetched = [
        for (final p in await fetch(PunishmentService.maxCount))
          if (seen.add(p.toLowerCase())) p,
      ];
      // Con muy pocos la ruleta repetiría castigos: mejor los de respaldo.
      if (fetched.length >= RouletteSetup.maxFields) {
        _current = List.unmodifiable(fetched);
      } else {
        debugPrint('[Ruleta] Directus tiene pocos castigos: ${fetched.length}');
      }
    } on Object catch (e) {
      debugPrint('[Ruleta] No se pudieron traer los castigos: $e');
      _loading = null;
    }
    return _current;
  }
}

/// Los castigos de Directus en la app; en las pruebas, solo los de
/// respaldo.
PunishmentPool defaultPunishmentPool() =>
    Platform.environment.containsKey('FLUTTER_TEST')
    ? PunishmentPool()
    : PunishmentPool(PunishmentService().fetchPunishments);
