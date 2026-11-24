import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/screens/letters_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:charadeando_app/widgets/bomb_explosion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../services/settings_test.dart' show MemorySettingsStore;

LettersTopic topic(int id, [String letters = 'ABCP']) => LettersTopic(
  id: '$id',
  topic: 'Temática $id',
  letters: LettersRules.lettersOf(letters),
);

/// Anota las partidas de Letras que se registran.
class _RecordingStats extends NoStatsService {
  final records = <(int, int)>[];

  @override
  Future<void> recordLetters({
    required int bombs,
    required int passes,
    required Duration averageFuse,
    required bool video,
  }) async => records.add((bombs, passes));
}

void main() {
  group('reglas', () {
    test('nunca salen la Ñ, la W, la X ni la Z', () {
      expect(LettersRules.letters, hasLength(23));
      for (final l in ['Ñ', 'W', 'X', 'Z']) {
        expect(LettersRules.letters, isNot(contains(l)));
      }
      expect(LettersRules.lettersOf('pstabc'), ['A', 'B', 'C', 'P', 'S', 'T']);
      expect(LettersRules.lettersOf('ab ñwxz b'), ['A', 'B']);
      // Sin letras válidas, todas las del juego.
      expect(LettersRules.lettersOf('ÑWXZ'), LettersRules.letters);
    });

    test('el tiempo secreto está entre 20 y 60 segundos', () {
      final random = Random(1);
      final seen = <int>{};
      for (var i = 0; i < 2000; i++) {
        final fuse = LettersRules.secretFuse(random).inSeconds;
        expect(fuse, inInclusiveRange(20, 60));
        seen.add(fuse);
      }
      // Salen todos los valores, también los extremos.
      expect(seen, containsAll([20, 60]));
      expect(seen, hasLength(41));
    });

    test('el tic-tac se acelera hasta el final', () {
      const fuse = Duration(seconds: 30);
      var previous = const Duration(days: 1);
      for (var s = 0; s <= 30; s++) {
        final interval = LettersRules.tickInterval(Duration(seconds: s), fuse);
        expect(interval, lessThanOrEqualTo(previous));
        previous = interval;
      }
      expect(
        LettersRules.tickInterval(Duration.zero, fuse),
        LettersRules.slowestTick,
      );
      expect(LettersRules.tickInterval(fuse, fuse), LettersRules.fastestTick);
    });

    test('cada bomba trae otra temática, una de sus letras y su tiempo', () {
      final game = LettersGame([
        topic(1, 'AB'),
        topic(2, 'CD'),
        topic(3, 'EF'),
      ], random: Random(3));
      final topics = <String>{};
      for (var i = 0; i < 3; i++) {
        game.nextBomb();
        topics.add(game.topic!.id);
        expect(game.topic!.letters, contains(game.letter));
        expect(game.fuse.inSeconds, inInclusiveRange(20, 60));
      }
      // No se repiten mientras alcancen.
      expect(topics, hasLength(3));
      // Y después vuelven.
      game.nextBomb();
      expect(topics, contains(game.topic!.id));
    });

    test('cuenta los pases de cada bomba y de la partida', () {
      final game = LettersGame([topic(1, 'P')], random: Random(1));
      game.nextBomb();
      game
        ..pass()
        ..pass()
        ..pass();
      final bomb = game.explode();
      expect(bomb.passes, 3);
      expect(bomb.summary, 'Temática 1 · La P · 3 pases');
      game.nextBomb();
      expect(game.passes, 0);
      game.pass();
      game.explode();
      expect(game.totalPasses, 4);
      expect(game.bombs, hasLength(2));
      expect(game.averageFuse.inSeconds, inInclusiveRange(20, 60));
      expect(game.bombs.last.summary, endsWith('1 pase'));
    });

    test('las estadísticas de Letras van como LETRAS', () {
      final stats = GameStats.letters(
        bombs: 3,
        passes: 40,
        averageFuse: const Duration(seconds: 35),
        video: true,
        version: '1.0.0+16',
      );
      expect(stats['modo'], 'LETRAS');
      expect(stats['categorias'], ['LETRAS']);
      expect(stats['rondas'], 3);
      expect(stats['duracion_turno'], 35);
      expect(stats['aciertos'], 40);
      expect(stats['pases'], 0);
      expect(stats['modo_acierto'], 'TOQUE');
    });

    test('el video lleva la temática, la letra y el BOOM', () {
      final ass = VideoRenderer.lettersSubtitles(
        topic: 'Cosas que hay en un baño',
        letter: 'P',
        playing: const Duration(seconds: 30),
        boomAt: const Duration(seconds: 30),
        end: const Duration(seconds: 32),
      );
      expect(ass, contains('PlayResX: 720'));
      expect(ass, contains('PlayResY: 1280'));
      expect(ass, contains('Topic,,0,0,0,,Cosas que hay en un baño'));
      expect(ass, contains('Letter,,0,0,0,,P'));
      expect(ass, contains('0:00:30.00,0:00:32.00,Boom'));
    });
  });

  group('temáticas del servidor', () {
    late Directory dir;
    late List<Map<String, dynamic>> requests;
    var online = true;
    final rows = [
      for (var i = 1; i <= 5; i++)
        {'id': i, 'tematica': 'Temática $i', 'letras': 'ABCDEFG'},
    ];

    LettersBank bank() => LettersBank(
      DirectusService(
        baseUrl: 'https://directus.test',
        client: MockClient((request) async {
          if (!online) throw const SocketException('sin red');
          expect(request.url.path, '/juego/tematicas');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requests.add(body);
          final excluded = (body['excluir'] as List).toSet();
          final data = [
            ...rows.where((r) => !excluded.contains(r['id'])),
            ...rows.where((r) => excluded.contains(r['id'])),
          ];
          return http.Response.bytes(
            utf8.encode(jsonEncode({'data': data})),
            200,
          );
        }),
      ),
      historyDirectory: () async => dir,
    );

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('tematicas');
      requests = [];
      online = true;
    });
    tearDown(() => dir.delete(recursive: true));

    test('pide las temáticas y no repite las ya jugadas', () async {
      final topics = await bank().prepare(includePremium: true);
      expect(topics, hasLength(5));
      expect(requests.single['n'], LettersBank.perGame);
      await bank().remember(topics.first);
      await bank().prepare(includePremium: false);
      expect(requests.last['excluir'], [int.parse(topics.first.id)]);
      expect(requests.last['incluir_premium'], isFalse);
    });

    test('sin internet avisa que hace falta conexión', () async {
      online = false;
      await expectLater(
        bank().prepare(includePremium: true),
        throwsA(
          isA<LettersException>().having((e) => e.offline, 'offline', isTrue),
        ),
      );
    });
  });

  group('pantalla', () {
    testWidgets('girar, pasar el celular y ¡BOOM!', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final stats = _RecordingStats();
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          statsServiceProvider.overrideWithValue(stats),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(settingsProvider.notifier)
          .update(const AppSettings(recordVideo: false));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: LettersScreen(random: Random(5), startWith: [topic(1, 'P')]),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('¡Girar!'), findsOneWidget);

      await tester.tap(find.text('¡Girar!'));
      // La ruleta gira y frena en la letra.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Temática 1'), findsOneWidget);
      expect(find.text('P'), findsOneWidget);
      expect(find.text('0 pases'), findsOneWidget);

      await tester.tap(find.text('¡Pasa!'));
      await tester.pump();
      expect(find.text('¡Pasa el celular!'), findsOneWidget);
      expect(find.text('1 pase'), findsOneWidget);
      // Dos toques seguidos cuentan uno.
      await tester.tap(find.text('¡Pasa!'));
      await tester.pump();
      expect(find.text('1 pase'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('¡Pasa!'));
      await tester.pump();
      expect(find.text('2 pases'), findsOneWidget);

      // Nadie sabe cuándo explota, pero nunca pasa de 60 segundos.
      for (
        var s = 0;
        s < 62 && find.byType(BombExplosion).evaluate().isEmpty;
        s++
      ) {
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      expect(find.byType(BombExplosion), findsOneWidget);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Perdió quien tenía el celular'), findsOneWidget);
      expect(find.textContaining('La P · 2 pases'), findsOneWidget);
      expect(find.text('Girar la ruleta de castigos'), findsOneWidget);
      expect(find.text('Otra bomba'), findsOneWidget);

      // Al salir se registra la partida.
      await tester.pumpWidget(const SizedBox());
      expect(stats.records, [(1, 2)]);
    });
  });
}
