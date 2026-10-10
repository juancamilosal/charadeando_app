import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:charadeando_app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory dir;
  late List<Map<String, dynamic>> collectionRequests;
  var online = true;
  var collection = <Map<String, String>>[];

  Map<String, String> word(String id, String frase, String categoria) => {
    'id': id,
    'frase': frase,
    'categoria': categoria,
  };

  WordBank bank() => WordBank(
    DirectusService(
      baseUrl: 'https://directus.test',
      client: MockClient((request) async {
        if (!online) throw const SocketException('sin red');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        collectionRequests.add(body);
        final excluded = (body['excluir'] as List).toSet();
        final data = [
          for (final w in collection)
            if (!excluded.contains(w['id'])) w,
        ].take(body['n'] as int).toList();
        return http.Response(jsonEncode({'data': data}), 200);
      }),
    ),
    directory: () async => dir,
    random: Random(1),
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('word_bank');
    collectionRequests = [];
    online = true;
    collection = [
      for (var i = 0; i < 20; i++) word('id$i', 'Palabra $i', 'ANIMALES'),
    ];
  });
  tearDown(() => dir.delete(recursive: true));

  test('trae de la colección la cantidad elegida', () async {
    final batch = await bank().load(4);
    expect(batch.offline, isFalse);
    expect(batch.words.map((w) => w.id), ['id0', 'id1', 'id2', 'id3']);
    expect(batch.words.first.category, 'ANIMALES');
    expect(collectionRequests.single['n'], 4);
  });

  test('no repite las palabras de la partida anterior', () async {
    await bank().load(5);
    final batch = await bank().load(5);
    expect(collectionRequests.last['excluir'], [
      'id0',
      'id1',
      'id2',
      'id3',
      'id4',
    ]);
    expect(batch.words.map((w) => w.id), ['id5', 'id6', 'id7', 'id8', 'id9']);
  });

  test('no juega dos veces la misma frase', () async {
    collection = [
      word('a', 'Perro', 'ANIMALES'),
      word('b', 'perro', 'ANIMALES'),
      word('c', 'Gato', 'ANIMALES'),
    ];
    final batch = await bank().load(3);
    expect(batch.words.map((w) => w.text), ['Perro', 'Gato']);
  });

  test('sin internet juega con el último lote guardado', () async {
    await bank().load(3);
    online = false;
    final batch = await bank().load(2);
    expect(batch.offline, isTrue);
    expect(batch.words, hasLength(2));
    expect(
      batch.words.map((w) => w.text),
      everyElement(isIn(['Palabra 0', 'Palabra 1', 'Palabra 2'])),
    );
  });

  test('sin internet y sin lote guardado avisa el error', () async {
    online = false;
    await expectLater(bank().load(5), throwsA(isA<DirectusException>()));
  });
}
