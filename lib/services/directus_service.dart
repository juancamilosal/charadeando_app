import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Habla con la ruta del juego en Directus (extensión en
/// `server/directus-extensions`). La colección no es pública: la app pide
/// palabras al azar con `POST /juego/palabras`.
class DirectusService {
  DirectusService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? defaultBaseUrl;

  /// Se puede cambiar al compilar con
  /// `--dart-define=DIRECTUS_URL=https://...`.
  static const defaultBaseUrl = String.fromEnvironment(
    'DIRECTUS_URL',
    defaultValue: 'https://charadeando.vps.webdock.cloud',
  );

  /// Máximo de palabras por petición. Debe coincidir con `MAX_COUNT` de la
  /// extensión.
  static const maxCount = 450;

  /// Máximo de ids ya jugados que se pueden excluir. Debe coincidir con
  /// `MAX_EXCLUDE` de la extensión.
  static const maxExclude = 500;

  static const _timeout = Duration(seconds: 15);

  final http.Client _client;
  final String baseUrl;

  Uri get wordsUri => Uri.parse('$baseUrl/juego/palabras');

  /// Trae [count] palabras al azar, de [category] y [difficulty] si se
  /// indican (códigos de Directus, como `ANIMALES` y `FACIL`). Las de
  /// [exclude] (ids ya jugados) solo se repiten si no alcanzan las demás.
  Future<List<RemoteWord>> fetchWords({
    required int count,
    String? category,
    String? difficulty,
    Iterable<String> exclude = const [],
  }) async {
    final excluded = exclude.toList();
    return _post(wordsUri, {
      'n': count.clamp(1, maxCount),
      'categoria': ?category,
      'dificultad': ?difficulty,
      'excluir': excluded.sublist(
        excluded.length > maxExclude ? excluded.length - maxExclude : 0,
      ),
    });
  }

  Future<List<RemoteWord>> _post(Uri uri, Map<String, Object> body) async {
    final payload = jsonEncode(body);
    debugPrint('[Directus] POST $uri $payload');
    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(_timeout);
    } on Exception catch (e) {
      debugPrint('[Directus] Sin respuesta: $e');
      throw DirectusException(null, 'No se pudo conectar con el servidor: $e');
    }
    final text = utf8.decode(response.bodyBytes);
    debugPrint('[Directus] ${response.statusCode} $text');

    if (response.statusCode != 200) {
      throw DirectusException(response.statusCode, text);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw DirectusException(
        response.statusCode,
        'Respuesta no válida: $text',
      );
    }
    final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
    if (data is! List) {
      throw DirectusException(
        response.statusCode,
        'Respuesta inesperada: falta la lista "data".',
      );
    }
    return [
      for (final item in data)
        if (item is Map<String, dynamic>) RemoteWord.fromJson(item),
    ];
  }
}

class DirectusException implements Exception {
  const DirectusException(this.statusCode, this.body);

  /// Código HTTP, o null si no hubo respuesta.
  final int? statusCode;
  final String body;

  /// Explicación en palabras simples de los errores más comunes.
  String get hint => switch (statusCode) {
    null => 'Revisa la conexión a internet y que Directus esté encendido.',
    404 =>
      'No existe la ruta del juego. Revisa que la extensión '
          'charadeando-juego esté instalada y actualizada en Directus.',
    429 => 'Demasiadas consultas seguidas. Espera un minuto.',
    _ => 'Directus respondió con un error.',
  };

  @override
  String toString() => 'DirectusException($statusCode): $body';
}
