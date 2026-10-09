import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Consulta las palabras guardadas en Directus.
class DirectusService {
  DirectusService({http.Client? client, String? baseUrl, String? collection})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? defaultBaseUrl,
      collection = collection ?? defaultCollection;

  /// Se puede cambiar al compilar con
  /// `--dart-define=DIRECTUS_URL=https://...`.
  static const defaultBaseUrl = String.fromEnvironment(
    'DIRECTUS_URL',
    defaultValue: 'https://charadeando.vps.webdock.cloud',
  );

  /// Se puede cambiar al compilar con
  /// `--dart-define=DIRECTUS_COLLECTION=...`.
  static const defaultCollection = String.fromEnvironment(
    'DIRECTUS_COLLECTION',
    defaultValue: 'palabras',
  );

  static const _timeout = Duration(seconds: 15);

  final http.Client _client;
  final String baseUrl;
  final String collection;

  Uri get wordsUri => Uri.parse(
    '$baseUrl/items/$collection',
  ).replace(queryParameters: {'fields': 'id,frase,categoria', 'limit': '-1'});

  Future<List<RemoteWord>> fetchWords() async {
    final uri = wordsUri;
    debugPrint('[Directus] GET $uri');
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on Exception catch (e) {
      debugPrint('[Directus] Sin respuesta: $e');
      throw DirectusException(null, 'No se pudo conectar con el servidor: $e');
    }
    debugPrint('[Directus] ${response.statusCode} ${response.body}');

    if (response.statusCode != 200) {
      throw DirectusException(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body);
    final data = body is Map<String, dynamic> ? body['data'] : null;
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
    401 || 403 =>
      'Directus negó el acceso. Dale permiso de lectura al rol Public '
          'sobre la colección.',
    404 => 'No existe la colección. Revisa que el nombre sea correcto.',
    _ => 'Directus respondió con un error.',
  };

  @override
  String toString() => 'DirectusException($statusCode): $body';
}
