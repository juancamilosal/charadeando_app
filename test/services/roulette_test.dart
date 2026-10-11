import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('elegir el campo', () {
    test('siempre es uno de los campos y todos pueden salir', () {
      final random = Random(1);
      final seen = <int>{};
      for (var i = 0; i < 500; i++) {
        final field = Roulette.pickField(7, random);
        expect(field, inInclusiveRange(0, 6));
        seen.add(field);
      }
      expect(seen, hasLength(7));
    });

    test('el campo bajo el indicador sigue el giro de la ruleta', () {
      // Sin girar, arriba empieza el campo 0.
      expect(Roulette.fieldAt(0.01, 4), 3);
      expect(Roulette.fieldAt(-0.01, 4), 0);
      // Un cuarto de vuelta a la derecha deja arriba el último campo.
      expect(Roulette.fieldAt(-pi / 2 - 0.01, 4), 1);
      expect(Roulette.fieldAt(pi / 2 + 0.01, 4), 2);
    });
  });

  group('ángulo final', () {
    for (final fields in [2, 3, 6, 10]) {
      test('cae justo en el centro del campo elegido con $fields campos', () {
        final seg = Roulette.segment(fields);
        for (final from in [0.0, 1.3, 25.7, -4.2]) {
          for (var field = 0; field < fields; field++) {
            final to = Roulette.stopAngle(
              from: from,
              field: field,
              fields: fields,
              minDistance: 30,
            );
            expect(Roulette.fieldAt(to, fields), field);
            // Al centro: medio campo a cada lado sigue siendo el mismo.
            expect(Roulette.fieldAt(to + seg * 0.49, fields), field);
            expect(Roulette.fieldAt(to - seg * 0.49, fields), field);
            final under = (-to) % (2 * pi);
            expect(under, closeTo((field + 0.5) * seg, 1e-9));
            // Recorre al menos la distancia pedida y menos de una vuelta más.
            expect(to - from, greaterThanOrEqualTo(30));
            expect(to - from, lessThan(30 + 2 * pi));
          }
        }
      });
    }

    test('el frenado empieza rápido y termina muy lento', () {
      expect(Roulette.easeOutQuart(0), 0);
      expect(Roulette.easeOutQuart(1), 1);
      expect(Roulette.easeOutQuart(0.2), greaterThan(0.55));
      final last = Roulette.easeOutQuart(1) - Roulette.easeOutQuart(0.9);
      final first = Roulette.easeOutQuart(0.1) - Roulette.easeOutQuart(0);
      expect(last, lessThan(first / 1000));
    });
  });

  group('grupos con menos puntos', () {
    test('un solo perdedor', () {
      expect(Roulette.losers([5, 2, 7]), [1]);
    });

    test('empate entre los de menos puntos: giran todos', () {
      expect(Roulette.losers([2, 5, 2, 7]), [0, 2]);
    });

    test('empate total: no hay castigo', () {
      expect(Roulette.losers([3, 3, 3]), isEmpty);
      expect(Roulette.losers([0, 0]), isEmpty);
    });
  });

  group('castigos', () {
    test('el sistema tiene unos 30 castigos distintos', () {
      expect(systemPunishments.length, greaterThanOrEqualTo(30));
      expect(systemPunishments.toSet(), hasLength(systemPunishments.length));
    });

    test('los del sistema salen sin repetir', () {
      final picked = Roulette.systemPick(10, Random(3));
      expect(picked, hasLength(10));
      expect(picked.toSet(), hasLength(10));
      expect(picked.every(systemPunishments.contains), isTrue);
    });

    test('mezclados: los escritos quedan en su campo y el juego completa '
        'los vacíos sin repetir', () {
      final written = ['Cantar el himno', '', '  ', 'Hacer 5 sentadillas'];
      final result = Roulette.completeMixed(written, 6, Random(7));
      expect(result, hasLength(6));
      expect(result[0], 'Cantar el himno');
      expect(result[3], 'Hacer 5 sentadillas');
      for (final i in [1, 2, 4, 5]) {
        expect(systemPunishments, contains(result[i]));
      }
      expect(result.toSet(), hasLength(6));
    });

    test('mezclados: no repite un castigo escrito que también es del '
        'sistema', () {
      final mine = systemPunishments.first;
      final result = Roulette.completeMixed(
        [mine, ''],
        2,
        Random(1),
        pool: [mine, 'Otro castigo'],
      );
      expect(result, [mine, 'Otro castigo']);
    });

    test('mezclados: si escriben todos, no se agrega ninguno', () {
      expect(Roulette.completeMixed(['A', 'B'], 2, Random(1)), ['A', 'B']);
    });
  });

  test('la ruleta configurada se guarda y se recupera', () async {
    final dir = await Directory.systemTemp.createTemp('ruleta');
    addTearDown(() => dir.delete(recursive: true));
    final store = PunishmentStore(directory: () async => dir);
    expect(await store.load(), isNull);

    await store.save(
      const RouletteSetup(
        source: PunishmentSource.mixed,
        punishments: ['Cantar', 'Bailar', 'Saltar'],
        written: ['Cantar', '', ''],
      ),
    );
    final loaded = (await store.load())!;
    expect(loaded.source, PunishmentSource.mixed);
    expect(loaded.punishments, ['Cantar', 'Bailar', 'Saltar']);
    expect(loaded.written, ['Cantar', '', '']);
    expect(loaded.fields, 3);
  });

  test('el servicio de Directus pide castigos a la ruta del juego', () async {
    late http.Request sent;
    final service = PunishmentService(
      baseUrl: 'https://directus.test',
      client: MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'data': [
              {'id': '1', 'texto': ' Cantar '},
              {'id': '2', 'texto': ''},
              {'id': '3'},
            ],
          }),
          200,
        );
      }),
    );
    expect(await service.fetchPunishments(8), ['Cantar']);
    expect(sent.url.path, '/juego/castigos');
    expect(jsonDecode(sent.body), {'n': 8});
  });
}
