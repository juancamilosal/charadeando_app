import 'dart:convert';

import 'package:http/http.dart' as http;

import 'directus_service.dart';

/// Castigos de la colección `castigos` de Directus, por una ruta del juego
/// (`POST /juego/castigos`) como la de las palabras.
///
/// TODAVÍA NO SE USA: la ruta no existe en la extensión y la ruleta usa
/// los castigos del sistema de `punishments.dart`. Cuando exista, la
/// ruleta puede pedir aquí los castigos y usar los locales sin internet.
class PunishmentService {
  PunishmentService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? DirectusService.defaultBaseUrl;

  static const _timeout = Duration(seconds: 15);

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
    } on Exception catch (e) {
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
