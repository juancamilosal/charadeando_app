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
  test('pide las palabras a la ruta del juego, no a la colección', () async {
    late http.Request sent;
    final service = DirectusService(
      baseUrl: 'https://directus.test',
      client: MockClient((request) async {
        sent = request;
        return http.Response('{"data":[]}', 200);
      }),
    );
    await service.fetchWords(count: 30, category: 'ANIMAL', exclude: ['a']);

    expect(sent.method, 'POST');
    expect(sent.url.path, '/juego/palabras');
    expect(jsonDecode(sent.body), {
      'n': 30,
      'categoria': 'ANIMAL',
      'excluir': ['a'],
    });
  });

  test('respeta los topes de la extensión', () async {
    late Map<String, dynamic> body;
    final service = DirectusService(
      baseUrl: 'https://directus.test',
      client: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"data":[]}', 200);
      }),
    );
    await service.fetchWords(
      count: 10000,
      exclude: [for (var i = 0; i < 600; i++) '$i'],
    );

    expect(body['n'], DirectusService.maxCount);
    expect(body.containsKey('categoria'), isFalse);
    final excluded = body['excluir'] as List;
    expect(excluded, hasLength(DirectusService.maxExclude));
    // Se quedan los más recientes, que están al final.
    expect(excluded.last, '599');
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
    final words = await service.fetchWords(count: 1);
    expect(words, hasLength(1));
    expect(words.single.frase, 'MOSCA');
    expect(words.single.categoria, 'ANIMAL');
    expect(words.single.id, '5211c755-d333-49bf-8d0d-9db9e52594ca');
  });

  test('explica cuando falta la extensión', () async {
    final service = serviceReturning(http.Response('{}', 404));
    await expectLater(
      service.fetchWords(count: 1),
      throwsA(
        isA<DirectusException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.hint, 'hint', contains('extensión')),
      ),
    );
  });

  test('avisa cuando no hay conexión', () async {
    final service = DirectusService(
      baseUrl: 'https://directus.test',
      client: MockClient((_) async => throw const SocketException('sin red')),
    );
    await expectLater(
      service.fetchWords(count: 1),
      throwsA(
        isA<DirectusException>().having((e) => e.statusCode, 'código', null),
      ),
    );
  });

  test('le pide a Gemini solo la cantidad, sin instrucciones', () async {
    late http.Request sent;
    final service = DirectusService(
      baseUrl: 'https://directus.test',
      client: MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'a', 'frase': 'Astronauta', 'categoria': 'LIBRE'},
            ],
          }),
          200,
        );
      }),
    );
    final words = await service.createWords(500);

    expect(sent.url.path, '/juego/crear');
    expect(jsonDecode(sent.body), {'n': DirectusService.maxCreate});
    expect(words.single.categoria, 'LIBRE');
  });
}
