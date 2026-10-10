import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Pide palabras a Gemini a través del flujo de Directus. La clave de Gemini
/// vive solo en el servidor; la app no la conoce.
class GeminiService {
  GeminiService({http.Client? client, String? flowUrl})
    : _client = client ?? http.Client(),
      flowUrl = flowUrl ?? defaultFlowUrl;

  /// Se puede cambiar al compilar con
  /// `--dart-define=GEMINI_FLOW_URL=https://...`.
  static const defaultFlowUrl = String.fromEnvironment(
    'GEMINI_FLOW_URL',
    defaultValue:
        'https://charadeando.vps.webdock.cloud/flows/trigger/'
        '2d91a34a-b82c-4f97-9e2f-12154ba86323',
  );

  static const instructions =
      'Responde SIEMPRE y ÚNICAMENTE con un array JSON de strings, sin '
      'explicaciones, sin markdown y sin texto fuera del array. Cada elemento '
      'debe ser una palabra o frase coherente (sustantivo, objeto, lugar, '
      'personaje o actividad) de entre 1 y 4 palabras, apta para que alguien '
      'la describa y otra persona la adivine en un juego. Ejemplo de '
      'respuesta válida: ["Peras", "Silla de caballo", "Una casa embrujada"]';

  /// Gemini puede tardar con listas largas.
  static const _timeout = Duration(seconds: 40);

  final http.Client _client;
  final String flowUrl;

  static Map<String, dynamic> requestBody(int count) => {
    'systemInstruction': {
      'parts': [
        {'text': instructions},
      ],
    },
    'contents': [
      {
        'role': 'user',
        'parts': [
          {
            'text':
                'Genera exactamente $count palabras o frases para el juego.',
          },
        ],
      },
    ],
  };

  /// Trae hasta [count] palabras o frases distintas.
  Future<List<String>> fetchWords(int count) async {
    final uri = Uri.parse(flowUrl);
    debugPrint('[Gemini] POST $uri ($count palabras)');
    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody(count)),
          )
          .timeout(_timeout);
    } on Exception catch (e) {
      debugPrint('[Gemini] Sin respuesta: $e');
      throw GeminiException(null, 'No se pudo conectar con el servidor: $e');
    }
    final body = utf8.decode(response.bodyBytes);
    debugPrint('[Gemini] ${response.statusCode} $body');
    if (response.statusCode != 200) {
      throw GeminiException(response.statusCode, body);
    }
    final words = parseWords(body);
    if (words.isEmpty) {
      throw GeminiException(
        response.statusCode,
        'La respuesta no trae una lista de palabras: $body',
      );
    }
    return words.take(count).toList();
  }

  /// Saca la lista de palabras de la respuesta del flujo. Acepta la lista
  /// directa, envuelta en `data`, la respuesta cruda de Gemini
  /// (`candidates[].content.parts[].text`) o el texto con la lista, aunque
  /// venga dentro de un bloque de markdown.
  @visibleForTesting
  static List<String> parseWords(String body) {
    final seen = <String>{};
    final words = <String>[];
    for (final item in _list(_tryJson(body) ?? body)) {
      final text = item.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (text.isNotEmpty && seen.add(text.toLowerCase())) words.add(text);
    }
    return words;
  }

  static List<String> _list(Object? value) {
    if (value is List) {
      if (value.every((e) => e is String)) return value.cast<String>();
      return [for (final e in value) ..._list(e)];
    }
    if (value is Map) {
      for (final key in ['data', 'candidates', 'content', 'parts', 'words']) {
        if (value.containsKey(key)) return _list(value[key]);
      }
      if (value['text'] is String) return _list(value['text']);
      return const [];
    }
    if (value is String) {
      // Texto con la lista adentro, quizá con ```json alrededor.
      final start = value.indexOf('[');
      final end = value.lastIndexOf(']');
      if (start == -1 || end <= start) return const [];
      final parsed = _tryJson(value.substring(start, end + 1));
      return parsed is List ? [for (final e in parsed) '$e'] : const [];
    }
    return const [];
  }

  static Object? _tryJson(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}

class GeminiException implements Exception {
  const GeminiException(this.statusCode, this.body);

  /// Código HTTP, o null si no hubo respuesta.
  final int? statusCode;
  final String body;

  @override
  String toString() => 'GeminiException($statusCode): $body';
}
