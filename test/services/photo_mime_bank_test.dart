import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory dir;
  late List<Map<String, dynamic>> requests;
  late List<String> downloads;
  late Set<String> broken;
  var online = true;
  var imagesOnline = true;
  var objects = <Map<String, Object>>[];

  Map<String, Object> object(int id, {bool premium = false}) => {
    'id': id,
    'nombre': 'Objeto $id',
    'imagen': 'foto-$id',
    'premium': premium,
  };

  DirectusService directus() => DirectusService(
    baseUrl: 'https://directus.test',
    client: MockClient((request) async {
      if (!online) throw const SocketException('sin red');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      final excluded = (body['excluir'] as List).toSet();
      final premium = body['incluir_premium'] == true;
      // Como la extensión: primero los no jugados y, si no alcanzan, los
      // jugados.
      final allowed = [
        for (final o in objects)
          if (premium || o['premium'] == false) o,
      ];
      final data = [
        ...allowed.where((o) => !excluded.contains(o['id'])),
        ...allowed.where((o) => excluded.contains(o['id'])),
      ].take(body['n'] as int).toList();
      return http.Response(jsonEncode({'data': data}), 200);
    }),
  );

  PhotoMimeBank bank() => PhotoMimeBank(
    directus(),
    client: MockClient((request) async {
      if (!imagesOnline) throw const SocketException('sin red');
      final id = request.url.pathSegments.last;
      downloads.add(id);
      if (broken.contains(id)) return http.Response('no existe', 404);
      // El primer byte 0 es una "foto dañada" para el validador de prueba.
      return http.Response.bytes(
        id.endsWith('-danada') ? [0, 1, 2] : [1, 2, 3],
        200,
      );
    }),
    historyDirectory: () async => dir,
    cacheDirectory: () async => dir,
    validate: (Uint8List bytes) async => bytes.first != 0,
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fotomimica');
    requests = [];
    downloads = [];
    broken = {};
    online = true;
    imagesOnline = true;
    objects = [for (var i = 1; i <= 20; i++) object(i)];
  });
  tearDown(() => dir.delete(recursive: true));

  test('el servicio pide los objetos y arma la dirección de la foto', () async {
    final items = await directus().fetchPhotoMime(
      count: 3,
      exclude: ['4', '5', 'x'],
      includePremium: true,
    );
    expect(requests.single, {
      'n': 3,
      'excluir': [4, 5],
      'incluir_premium': true,
    });
    expect(items.map((i) => i.nombre), ['Objeto 1', 'Objeto 2', 'Objeto 3']);
    expect(
      items.first.imageUrl,
      'https://directus.test/assets/foto-1?width=720&quality=80&format=webp',
    );
    expect(directus().photoMimeUri.path, '/juego/fotomimica');
  });

  test('descarga todas las fotos antes de jugar y avisa el progreso', () async {
    final progress = <(int, int)>[];
    final words = await bank().prepare(
      5,
      includePremium: false,
      onProgress: (ready, total) => progress.add((ready, total)),
    );
    expect(words, hasLength(5));
    expect(progress.first, (0, 5));
    expect(progress.last, (5, 5));
    for (final w in words) {
      expect(w.category, GameCategory.photoMime.code);
      expect(File(w.image!).existsSync(), isTrue, reason: w.text);
    }
    // Pide algunos de más por si alguna foto falla.
    expect(requests.single['n'], 5 + PhotoMimeBank.spare);
    expect(requests.single['incluir_premium'], isFalse);
  });

  test('si una foto falla se reemplaza por otro objeto', () async {
    broken = {'foto-1', 'foto-3'};
    objects[1] = {...objects[1], 'imagen': 'foto-2-danada'};
    final words = await bank().prepare(4, includePremium: false);
    expect(words, hasLength(4));
    final names = words.map((w) => w.text).toSet();
    expect(names.intersection({'Objeto 1', 'Objeto 2', 'Objeto 3'}), isEmpty);
  });

  test('recuerda los ya jugados para no repetirlos en la siguiente', () async {
    final first = await bank().prepare(5, includePremium: false);
    await bank().prepare(5, includePremium: false);
    expect(
      requests.last['excluir'],
      containsAll([for (final w in first) int.parse(w.id!)]),
    );
  });

  test('una foto ya descargada no se vuelve a bajar', () async {
    objects = [for (var i = 1; i <= 3; i++) object(i)];
    await bank().prepare(3, includePremium: false);
    expect(downloads, hasLength(3));
    await bank().prepare(3, includePremium: false);
    expect(downloads, hasLength(3));
  });

  test('sin Premium solo los gratis; con Premium, todos', () async {
    objects = [object(1), object(2, premium: true)];
    final free = await bank().prepare(5, includePremium: false);
    expect(free.map((w) => w.text), ['Objeto 1']);
    final all = await bank().prepare(5, includePremium: true);
    expect(all.map((w) => w.text).toSet(), {'Objeto 1', 'Objeto 2'});
  });

  test('sin internet no deja empezar y lo dice claro', () async {
    online = false;
    await expectLater(
      bank().prepare(5, includePremium: false),
      throwsA(
        isA<PhotoMimeException>()
            .having((e) => e.offline, 'offline', isTrue)
            .having((e) => e.message, 'message', contains('internet')),
      ),
    );
    // Llegan los objetos pero no se pueden bajar las fotos.
    online = true;
    imagesOnline = false;
    await expectLater(
      bank().prepare(5, includePremium: false),
      throwsA(
        isA<PhotoMimeException>().having((e) => e.offline, 'offline', isTrue),
      ),
    );
  });

  test('con menos objetos de los necesarios no se puede jugar', () async {
    objects = [object(1)];
    await expectLater(
      bank().prepare(5, includePremium: false, minimum: 2),
      throwsA(
        isA<PhotoMimeException>().having((e) => e.offline, 'offline', isFalse),
      ),
    );
  });
}
