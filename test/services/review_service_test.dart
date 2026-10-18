import 'dart:io';

import 'package:charadeando_app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePrompt implements ReviewPrompt {
  _FakePrompt({this.available = true});

  final bool available;
  int requested = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> request() async => requested++;

  @override
  Future<void> openStore() async {}
}

void main() {
  final now = DateTime(2026, 11, 20, 18);

  bool ask({
    int games = 3,
    bool winner = true,
    bool errors = false,
    DateTime? lastAsked,
  }) => ReviewPolicy.shouldAsk(
    finishedGames: games,
    hasWinner: winner,
    hadErrors: errors,
    lastAsked: lastAsked,
    now: now,
  );

  group('cuándo se pide la reseña', () {
    test('sí: 3.ª partida terminada o más, con ganador, sin errores y nunca '
        'pedida', () {
      expect(ask(), isTrue);
      expect(ask(games: 10), isTrue);
    });

    test('sí: la última vez fue hace 30 días o más', () {
      expect(ask(lastAsked: now.subtract(const Duration(days: 30))), isTrue);
      expect(ask(lastAsked: now.subtract(const Duration(days: 90))), isTrue);
    });

    test('no: antes de la 3.ª partida', () {
      expect(ask(games: 0), isFalse);
      expect(ask(games: 1), isFalse);
      expect(ask(games: 2), isFalse);
    });

    test('no: empate o sin ganador', () {
      expect(ask(winner: false), isFalse);
    });

    test('no: hubo errores en la partida', () {
      expect(ask(errors: true), isFalse);
    });

    test('no: se pidió en los últimos 30 días', () {
      expect(ask(lastAsked: now.subtract(const Duration(days: 29))), isFalse);
      expect(ask(lastAsked: now.subtract(const Duration(hours: 1))), isFalse);
    });
  });

  group('ReviewService', () {
    late Directory dir;
    late ReviewStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('resena');
      store = ReviewStore(directory: () async => dir);
    });
    tearDown(() => dir.delete(recursive: true));

    test('cuenta las partidas terminadas en el celular y pide la reseña '
        'desde la 3.ª', () async {
      final prompt = _FakePrompt();
      final service = ReviewService(
        store: store,
        prompt: prompt,
        clock: () => now,
      );
      expect(
        await service.gameFinished(hasWinner: true, hadErrors: false),
        isFalse,
      );
      expect(
        await service.gameFinished(hasWinner: true, hadErrors: false),
        isFalse,
      );
      expect(
        await service.gameFinished(hasWinner: true, hadErrors: false),
        isTrue,
      );
      expect((await store.load()).finishedGames, 3);

      await service.ask();
      expect(prompt.requested, 1);
      final saved = await store.load();
      expect(saved.lastAsked, now);
      expect(saved.finishedGames, 3);
      // Recién pedida: la siguiente partida no la vuelve a pedir.
      expect(
        await service.gameFinished(hasWinner: true, hadErrors: false),
        isFalse,
      );
    });

    test('un empate o un error cuentan la partida, pero no piden', () async {
      final service = ReviewService(
        store: store,
        prompt: _FakePrompt(),
        clock: () => now,
      );
      await store.save(const ReviewRecord(finishedGames: 5));
      expect(
        await service.gameFinished(hasWinner: false, hadErrors: false),
        isFalse,
      );
      expect(
        await service.gameFinished(hasWinner: true, hadErrors: true),
        isFalse,
      );
      expect((await store.load()).finishedGames, 7);
    });

    test('sin Google Play no pide ni guarda la fecha', () async {
      final prompt = _FakePrompt(available: false);
      final service = ReviewService(store: store, prompt: prompt);
      await service.ask();
      expect(prompt.requested, 0);
      expect((await store.load()).lastAsked, isNull);
    });

    test('un archivo dañado empieza de cero', () async {
      await File('${dir.path}/resena.json').writeAsString('{roto');
      expect((await store.load()).finishedGames, 0);
    });
  });
}
