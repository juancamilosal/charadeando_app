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

    test('cada bomba trae otra temática con su rueda de letras', () {
      final game = LettersGame([
        topic(1, 'AB'),
        topic(2, 'CD'),
        topic(3, 'EF'),
      ], random: Random(3));
      final topics = <String>{};
      for (var i = 0; i < 3; i++) {
        game.nextBomb();
        topics.add(game.topic!.id);
        // La rueda tiene las 23 letras, sea cual sea la temática.
        expect(game.letters, LettersRules.letters);
        expect(game.round, 1);
        expect(game.used, isEmpty);
        expect(game.fuse.inSeconds, inInclusiveRange(20, 60));
      }
      // No se repiten mientras alcancen.
      expect(topics, hasLength(3));
      // Y después vuelven.
      game.nextBomb();
      expect(topics, contains(game.topic!.id));
    });

    test('cada letra se usa una vez por ronda; al usarlas todas termina '
        'la ronda y en la siguiente se dice una palabra más', () {
      final game = LettersGame([topic(1, 'ABC')], random: Random(1));
      game.nextBomb();
      expect(game.wordsPerPass, 1);
      expect(game.choose('A'), isFalse);
      // Repetida o fuera de la rueda (Ñ, W, X, Z): no cuenta.
      expect(game.choose('A'), isFalse);
      expect(game.choose('Z'), isFalse);
      expect(game.choose('Ñ'), isFalse);
      expect(game.passes, 1);
      // Todas las letras se pueden usar, también las difíciles.
      final rest = [
        for (final l in LettersRules.letters)
          if (l != 'A') l,
      ];
      for (final l in rest.take(rest.length - 1)) {
        expect(game.choose(l), isFalse, reason: l);
      }
      expect(game.roundOver, isFalse);
      expect(game.choose(rest.last), isTrue);
      expect(game.roundOver, isTrue);
      expect(game.passes, 23);
      game.nextRound();
      expect(game.round, 2);
      expect(game.wordsPerPass, 2);
      expect(game.used, isEmpty);
      // Las letras vuelven a quedar libres.
      expect(game.choose('A'), isFalse);
      expect(game.passes, 24);
      final bomb = game.explode();
      expect(bomb.round, 2);
      expect(bomb.summary, 'Temática 1 · 24 pases · ronda 2');
      expect(LettersGame.number(2), 'dos');
      expect(LettersGame.number(3), 'tres');
    });

    test('cuenta los pases de la partida', () {
      final game = LettersGame([topic(1, 'PQRS')], random: Random(1));
      game.nextBomb();
      game
        ..choose('P')
        ..choose('Q');
      game.explode();
      game.nextBomb();
      expect(game.passes, 0);
      game.choose('S');
      game.explode();
      expect(game.totalPasses, 3);
      expect(game.bombs, hasLength(2));
      expect(game.averageFuse.inSeconds, inInclusiveRange(20, 60));
      expect(game.bombs.last.summary, 'Temática 1 · 1 pase');
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

    test('el video lleva la temática, cada letra, la ronda y la explosión', () {
      final ass = VideoRenderer.lettersSubtitles(
        topic: 'Cosas que hay en un baño',
        picks: const [(Duration(seconds: 2), 'P'), (Duration(seconds: 5), 'J')],
        notices: const [
          (
            Duration(seconds: 8),
            Duration(seconds: 10),
            'Ronda 1 finalizada · Ahora, dos palabras',
          ),
        ],
        boomAt: const Duration(seconds: 30),
        end: const Duration(seconds: 32),
      );
      expect(ass, contains('PlayResX: 720'));
      expect(ass, contains('PlayResY: 1280'));
      expect(
        ass,
        contains(
          '0:00:00.00,0:00:30.00,Topic,,0,0,0,,Cosas que hay en un baño',
        ),
      );
      expect(ass, contains('0:00:02.00,0:00:03.20,Letter'));
      expect(ass, contains('0:00:05.00,0:00:06.20,Letter'));
      expect(ass, contains('Notice,,0,0,0,,Ronda 1 finalizada'));
      expect(ass, contains('0:00:30.00,0:00:32.00,Boom'));
      // La explosión: oscuro, bola de fuego, chispas y destello.
      expect(
        RegExp(r'Dialogue: \d+,0:00:30\.\d\d,[^,]+,Fx').allMatches(ass).length,
        greaterThan(40),
      );
      expect(ass, contains(r'\move(360,640,'));
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
    testWidgets('al usar todas las letras termina la ronda y la bomba se '
        'pausa', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          statsServiceProvider.overrideWithValue(NoStatsService()),
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
            home: LettersScreen(random: Random(5), startWith: [topic(1, 'AB')]),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('¡Empezar!'));
      await tester.pump();
      // Las 23 letras están en la rueda.
      for (final l in LettersRules.letters) {
        expect(find.text(l), findsOneWidget, reason: l);
      }
      for (final l in LettersRules.letters) {
        await tester.tap(find.text(l));
        await tester.pump(const Duration(milliseconds: 600));
      }
      expect(find.text('Ronda 1 finalizada'), findsOneWidget);
      expect(
        find.text('Ahora debes mencionar dos palabras para pasar'),
        findsOneWidget,
      );
      // En pausa la bomba no explota, aunque pase más del máximo.
      for (var s = 0; s < 70; s++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byType(BombExplosion), findsNothing);
      await tester.tap(find.text('¡Seguir!'));
      await tester.pump();
      expect(find.textContaining('Ronda 2 · Di dos palabras'), findsOneWidget);
      expect(find.text('23 pases'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

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
            home: LettersScreen(
              random: Random(5),
              startWith: [topic(1, 'APS')],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('¡Empezar!'), findsOneWidget);

      await tester.tap(find.text('¡Empezar!'));
      await tester.pump();
      expect(find.text('Temática 1'), findsOneWidget);
      expect(find.text('0 pases'), findsOneWidget);
      expect(find.textContaining('Ronda 1 · Di una palabra'), findsOneWidget);

      await tester.tap(find.text('P'));
      await tester.pump();
      expect(find.text('¡Pasa el celular!'), findsOneWidget);
      expect(find.text('1 pase'), findsOneWidget);
      // Dos toques seguidos cuentan uno.
      await tester.tap(find.text('A'));
      await tester.pump();
      expect(find.text('1 pase'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('A'));
      await tester.pump();
      expect(find.text('2 pases'), findsOneWidget);
      // La P ya está usada: no cuenta otra vez.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('P'));
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
      expect(find.textContaining('2 pases · ronda 1'), findsOneWidget);
      expect(find.text('Girar la ruleta de castigos'), findsOneWidget);
      expect(find.text('Otra bomba'), findsOneWidget);

      // Al salir se registra la partida.
      await tester.pumpWidget(const SizedBox());
      expect(stats.records, [(1, 2)]);
    });
  });
}
