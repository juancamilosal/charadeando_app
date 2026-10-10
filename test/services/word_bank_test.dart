import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:charadeando_app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory dir;
  late List<Map<String, dynamic>> directusRequests;
  var online = true;
  var geminiWorks = true;
  var geminiWords = <String>[];

  WordBank bank() => WordBank(
    GeminiService(
      flowUrl: 'https://directus.test/flows/trigger/abc',
      client: MockClient((request) async {
        if (!online) throw const SocketException('sin red');
        if (!geminiWorks) return http.Response('{"errors":[]}', 500);
        return http.Response(jsonEncode(geminiWords), 200);
      }),
    ),
    DirectusService(
      baseUrl: 'https://directus.test',
      client: MockClient((request) async {
        if (!online) throw const SocketException('sin red');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        directusRequests.add(body);
        final excluded = (body['excluir'] as List).toSet();
        final words = [
          for (var i = 0; i < 20; i++)
            if (!excluded.contains('id$i'))
              {'id': 'id$i', 'frase': 'Palabra $i', 'categoria': 'ANIMAL'},
        ].take(body['n'] as int).toList();
        return http.Response(jsonEncode({'data': words}), 200);
      }),
    ),
    directory: () async => dir,
    random: Random(1),
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('word_bank');
    directusRequests = [];
    online = true;
    geminiWorks = true;
    geminiWords = ['Peras', 'Silla de caballo', 'Una casa embrujada'];
  });
  tearDown(() => dir.delete(recursive: true));

  test('usa las palabras de Gemini', () async {
    final batch = await bank().load(3);
    expect(batch.offline, isFalse);
    expect(batch.words.map((w) => w.text), geminiWords);
    expect(batch.words.first.id, isNull);
    expect(directusRequests, isEmpty);
  });

  test('si Gemini falla, usa la colección de Directus', () async {
    geminiWorks = false;
    final batch = await bank().load(3);
    expect(batch.words.map((w) => w.id), ['id0', 'id1', 'id2']);
  });

  test('si Gemini trae menos, completa con Directus', () async {
    final batch = await bank().load(5);
    expect(batch.words, hasLength(5));
    expect(directusRequests.single['n'], 2);
  });

  test('no repite palabras de Gemini jugadas hace poco', () async {
    await bank().load(3);
    geminiWords = ['peras', 'Mango', 'Silla de caballo'];
    final batch = await bank().load(3);
    expect(batch.words.map((w) => w.text), ['Mango', 'Palabra 0', 'Palabra 1']);
  });

  test('no repite las palabras de Directus de la partida anterior', () async {
    geminiWorks = false;
    await bank().load(5);
    await bank().load(5);
    expect(directusRequests.last['excluir'], [
      'id0',
      'id1',
      'id2',
      'id3',
      'id4',
    ]);
  });

  test('sin internet juega con el último lote guardado', () async {
    await bank().load(3);
    online = false;
    final batch = await bank().load(2);
    expect(batch.offline, isTrue);
    expect(batch.words, hasLength(2));
    expect(batch.words.map((w) => w.text), everyElement(isIn(geminiWords)));
  });

  test('sin internet y sin lote guardado avisa el error', () async {
    online = false;
    await expectLater(bank().load(5), throwsA(isA<DirectusException>()));
  });
}
