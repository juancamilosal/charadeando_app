import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory dir;
  late List<Map<String, dynamic>> requests;
  var online = true;

  Map<String, Object> word(int i) => {
    'id': 'id$i',
    'frase': 'Palabra $i',
    'categoria': 'ANIMAL',
  };

  WordBank bank() => WordBank(
    DirectusService(
      baseUrl: 'https://directus.test',
      client: MockClient((request) async {
        if (!online) throw const SocketException('sin red');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(body);
        final excluded = (body['excluir'] as List).toSet();
        final words = [
          for (var i = 0; i < 20; i++)
            if (!excluded.contains('id$i')) word(i),
        ].take(body['n'] as int).toList();
        return http.Response(jsonEncode({'data': words}), 200);
      }),
    ),
    directory: () async => dir,
    random: Random(1),
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('word_bank');
    requests = [];
    online = true;
  });
  tearDown(() => dir.delete(recursive: true));

  test('no repite las palabras de la partida anterior', () async {
    final first = await bank().load(5);
    expect(first.offline, isFalse);
    expect(first.words.map((w) => w.id), ['id0', 'id1', 'id2', 'id3', 'id4']);

    final second = await bank().load(5);
    expect(requests.last['excluir'], ['id0', 'id1', 'id2', 'id3', 'id4']);
    expect(second.words.map((w) => w.id), ['id5', 'id6', 'id7', 'id8', 'id9']);
  });

  test('sin internet juega con el último lote guardado', () async {
    await bank().load(5);
    online = false;
    final batch = await bank().load(3);
    expect(batch.offline, isTrue);
    expect(batch.words, hasLength(3));
    expect(
      batch.words.map((w) => w.id),
      everyElement(isIn(['id0', 'id1', 'id2', 'id3', 'id4'])),
    );
  });

  test('sin internet y sin lote guardado avisa el error', () async {
    online = false;
    await expectLater(bank().load(5), throwsA(isA<DirectusException>()));
  });

  test('las palabras extra no repiten las que están en juego', () async {
    final batch = await bank().load(3);
    final playing = [...batch.words, Word('Escrita', id: 'id3')];
    final more = await bank().more(2, playing);
    expect(requests.last['excluir'], containsAll(['id0', 'id1', 'id2', 'id3']));
    expect(more.map((w) => w.id), ['id4', 'id5']);
  });

  test('sin internet no hay palabras extra, pero no falla', () async {
    online = false;
    expect(await bank().more(5, const []), isEmpty);
  });
}
