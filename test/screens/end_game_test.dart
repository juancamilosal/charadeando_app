import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/turn_result_screen.dart';
import 'package:charadeando_app/screens/turn_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _groups = [Group('Tigres'), Group('Águilas')];

/// Sin carpeta de videos de verdad.
class _NoVideos extends VideoService {
  int deleted = 0;

  @override
  Future<void> deleteAll() async => deleted++;
}

ProviderContainer _game({bool played = false}) {
  final container = ProviderContainer(
    overrides: [
      tvConnectedProvider.overrideWith((ref) => Stream.value(false)),
      videoServiceProvider.overrideWithValue(_NoVideos()),
    ],
  );
  final game = container.read(gameControllerProvider.notifier);
  game.configure(
    const GameConfig(
      groups: _groups,
      hitMode: HitMode.tilt,
      scoringMode: ScoringMode.perPhrase,
      resolution: VideoResolution.off,
    ),
  );
  game.startWithDecks([
    [Word('Pizza'), Word('Jirafa')],
    [Word('Titanic'), Word('Shakira')],
  ]);
  if (played) {
    game.finishTurn(
      Turn(
        round: 1,
        groupIndex: 0,
        entries: [TurnEntry(Word('Pizza'), WordOutcome.hit)],
      ),
    );
  }
  return container;
}

Future<void> _show(
  WidgetTester tester,
  ProviderContainer container,
  String initial,
) async {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (_) async => null,
  );
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: Routes.turn, builder: (_, _) => const TurnScreen()),
      GoRoute(
        path: Routes.turnResult,
        builder: (_, _) => const TurnResultScreen(),
      ),
      GoRoute(path: Routes.finalResult, builder: (_, _) => const Text('Final')),
      GoRoute(path: Routes.welcome, builder: (_, _) => const Text('Inicio')),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _endGame(WidgetTester tester, {bool confirm = true}) async {
  await tester.tap(find.text('Finalizar juego'));
  await tester.pumpAndSettle();
  expect(find.text('¿Finalizar el juego?'), findsOneWidget);
  await tester.tap(find.text(confirm ? 'Finalizar' : 'Seguir jugando'));
  await tester.pumpAndSettle();
}

void main() {
  test('finalizar la partida la deja terminada con los turnos jugados', () {
    final container = _game(played: true);
    addTearDown(container.dispose);
    container.read(gameControllerProvider.notifier).endGame();
    final state = container.read(gameControllerProvider);
    expect(state.finished, isTrue);
    expect(state.scores, [1, 0]);
  });

  testWidgets('antes del turno se puede finalizar y ver los puntajes', (
    tester,
  ) async {
    final container = _game(played: true);
    addTearDown(container.dispose);
    container.read(gameControllerProvider.notifier).advance();
    await _show(tester, container, Routes.turn);
    expect(find.text('Turno de Águilas'), findsOneWidget);

    await _endGame(tester, confirm: false);
    expect(find.text('Turno de Águilas'), findsOneWidget);

    await _endGame(tester);
    expect(find.text('Final'), findsOneWidget);
    expect(container.read(gameControllerProvider).finished, isTrue);
  });

  testWidgets('si nadie ha jugado, finalizar vuelve al inicio', (tester) async {
    final container = _game();
    addTearDown(container.dispose);
    await _show(tester, container, Routes.turn);
    await _endGame(tester);
    expect(find.text('Inicio'), findsOneWidget);
  });

  testWidgets('en la tabla de puntajes se puede finalizar el juego', (
    tester,
  ) async {
    final container = _game(played: true);
    addTearDown(container.dispose);
    await _show(tester, container, Routes.turnResult);
    expect(find.text('Continuar'), findsOneWidget);
    await _endGame(tester);
    expect(find.text('Final'), findsOneWidget);
    expect(container.read(gameControllerProvider).finished, isTrue);
  });
}
