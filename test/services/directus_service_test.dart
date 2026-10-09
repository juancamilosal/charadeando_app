import 'dart:convert';
import 'dart:io';

import 'package:charadeando_app/services/directus_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

DirectusService serviceReturning(http.Response response) => DirectusService(
  baseUrl: 'https://directus.test',
  client: MockClient((request) async => response),
);

void main() {
  test('consulta la colección con los campos de la palabra', () {
    final uri = DirectusService(baseUrl: 'https://directus.test').wordsUri;
    expect(uri.path, '/items/palabras');
    expect(uri.queryParameters['fields'], 'id,frase,categoria');
  });

  test('convierte la respuesta de Directus en palabras', () async {
    final service = serviceReturning(
      http.Response(
        jsonEncode({
          'data': [
            {
              'id': '5211c755-d333-49bf-8d0d-9db9e52594ca',
              'frase': 'MOSCA',
              'categoria': 'ANIMAL',
            },
          ],
        }),
        200,
      ),
    );
    final words = await service.fetchWords();
    expect(words, hasLength(1));
    expect(words.single.frase, 'MOSCA');
    expect(words.single.categoria, 'ANIMAL');
    expect(words.single.id, '5211c755-d333-49bf-8d0d-9db9e52594ca');
  });

  test('explica cuando falta el permiso del rol Public', () async {
    final service = serviceReturning(
      http.Response('{"errors":[{"message":"Forbidden"}]}', 403),
    );
    await expectLater(
      service.fetchWords(),
      throwsA(
        isA<DirectusException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.hint, 'hint', contains('rol Public')),
      ),
    );
  });

  test('avisa cuando no hay conexión', () async {
    final service = DirectusService(
      baseUrl: 'https://directus.test',
      client: MockClient((_) async => throw const SocketException('sin red')),
    );
    await expectLater(
      service.fetchWords(),
      throwsA(
        isA<DirectusException>().having((e) => e.statusCode, 'código', null),
      ),
    );
  });
}
