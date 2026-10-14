import 'dart:convert';

import 'package:http/http.dart' as http;

import 'directus_service.dart';

/// Lo que abre un código: todo, o algunas categorías (por su código, como
/// `ANIME`).
class CodeUnlock {
  const CodeUnlock({this.all = false, this.categories = const {}});

  final bool all;
  final Set<String> categories;

  /// No abre nada (por ejemplo, un celular sin códigos canjeados).
  bool get isEmpty => !all && categories.isEmpty;
}

/// El código no sirve; [message] dice por qué, para mostrarlo tal cual.
class CodeException implements Exception {
  const CodeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Canjea códigos promocionales con la ruta del juego
/// (`POST /juego/canjear`), que revisa que existan, sigan vigentes y les
/// queden usos.
class PromoCodeService {
  PromoCodeService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? DirectusService.defaultBaseUrl;

  static const _timeout = Duration(seconds: 15);

  final http.Client _client;
  final String baseUrl;

  Uri get redeemUri => Uri.parse('$baseUrl/juego/canjear');
  Uri get restoreUri => Uri.parse('$baseUrl/juego/mis-codigos');

  Future<CodeUnlock> redeem(String code, {required String device}) =>
      _post(redeemUri, {'codigo': code.trim(), 'dispositivo': device});

  /// Lo que abren los códigos que este celular ya canjeó (no gasta usos).
  Future<CodeUnlock> restore({required String device}) =>
      _post(restoreUri, {'dispositivo': device});

  Future<CodeUnlock> _post(Uri uri, Map<String, Object> body) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on Exception {
      throw const CodeException(
        'No hay conexión. Revisa el internet e inténtalo otra vez.',
      );
    }
    Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      json = null;
    }
    if (response.statusCode != 200) {
      Object? message;
      final errors = json is Map<String, dynamic> ? json['errors'] : null;
      if (errors is List && errors.isNotEmpty && errors.first is Map) {
        message = (errors.first as Map)['message'];
      }
      // Directus responde "Route ... doesn't exist." si la extensión del
      // servidor todavía no tiene la ruta.
      if (message is String && message.startsWith('Route ')) {
        throw const CodeException(
          'Los códigos todavía no están disponibles. Inténtalo más tarde.',
        );
      }
      throw CodeException(
        message is String ? message : 'No se pudo canjear el código.',
      );
    }
    final data = json is Map<String, dynamic> ? json['data'] : null;
    if (data is! Map<String, dynamic>) {
      throw const CodeException('No se pudo canjear el código.');
    }
    return CodeUnlock(
      all: data['todo'] == true,
      categories: {
        for (final c in data['categorias'] as List? ?? const [])
          if (c is String) c.toUpperCase(),
      },
    );
  }
}
