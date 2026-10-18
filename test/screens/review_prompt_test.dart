import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/final_result_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'roulette_screen_test.dart' show MemoryStore;

/// Lo de la reseña en memoria, sin archivos.
class _MemoryReviewStore extends ReviewStore {
  _MemoryReviewStore(this.record);

  ReviewRecord record;

  @override
  Future<ReviewRecord> load() async => record;

  @override
  Future<void> save(ReviewRecord record) async => this.record = record;
}

class _FakePrompt implements ReviewPrompt {
  int requested = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> request() async => requested++;

  @override
  Future<void> openStore() async {}
}

void main() {
  late _FakePrompt prompt;
  late _MemoryReviewStore store;

  /// El resultado final de una partida con esos aciertos por equipo, ya
  /// con [played] partidas terminadas antes.
  Future<void> finalScreen(
    WidgetTester tester,
    List<int> hitsPerGroup, {
    int played = 2,
  }) async {
    tester.view.physicalSize = const Size(1080, 3600);
    addTearDown(tester.view.reset);
    prompt = _FakePrompt();
    store = _MemoryReviewStore(ReviewRecord(finishedGames: played));
    final container = ProviderContainer(
      overrides: [
        punishmentStoreProvider.overrideWithValue(MemoryStore()),
        reviewServiceProvider.overrideWithValue(
          ReviewService(store: store, prompt: prompt),
        ),
      ],
    );
    addTearDown(container.dispose);
    final game = container.read(gameControllerProvider.notifier);
    game.configure(
      GameConfig(
        groups: [
          for (final name in ['Tigres', 'Águilas'].take(hitsPerGroup.length))
            Group(name),
        ],
        scoringMode: ScoringMode.perPhrase,
      ),
    );
    game.startWithDecks([for (final _ in hitsPerGroup) const <Word>[]]);
    for (var g = 0; g < hitsPerGroup.length; g++) {
      game.finishTurn(
        Turn(
          round: 1,
          groupIndex: g,
          entries: [
            for (var i = 0; i < hitsPerGroup[g]; i++)
              TurnEntry(Word('p$g$i'), WordOutcome.hit),
          ],
        ),
      );
    }
    game.endGame();
    final router = GoRouter(
      initialLocation: Routes.finalResult,
      routes: [
        GoRoute(
          path: Routes.finalResult,
          builder: (_, _) => const FinalResultScreen(),
        ),
        GoRoute(
          path: Routes.punishmentSpin,
          builder: (_, _) => const Scaffold(body: Text('Ruleta')),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  testWidgets('en la 3.ª partida con ganador se pide la reseña unos 2 '
      'segundos después de ver al ganador', (tester) async {
    await finalScreen(tester, [3, 1]);
    expect(find.text('¡Ganó Tigres!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(store.record.finishedGames, 3);
    expect(prompt.requested, 0);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(prompt.requested, 1);
    expect(store.record.lastAsked, isNotNull);
  });

  testWidgets('antes de la 3.ª partida no se pide', (tester) async {
    await finalScreen(tester, [3, 1], played: 1);
    await tester.pump(const Duration(seconds: 3));
    expect(prompt.requested, 0);
    expect(store.record.finishedGames, 2);
  });

  testWidgets('con empate no se pide', (tester) async {
    await finalScreen(tester, [2, 2]);
    await tester.pump(const Duration(seconds: 3));
    expect(prompt.requested, 0);
  });

  testWidgets('si abren la ruleta antes, no se pide encima de ella', (
    tester,
  ) async {
    await finalScreen(tester, [3, 1]);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text('Girar'));
    await tester.tap(find.text('Girar'));
    await tester.pumpAndSettle();
    expect(find.text('Ruleta'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(prompt.requested, 0);
  });
}
