import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/team_editor_screen.dart';
import 'package:charadeando_app/screens/teams_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'config_screen_test.dart' show MemoryTeamStore;

Future<void> _pump(WidgetTester tester, MemoryTeamStore store) async {
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Routes.teams,
    routes: [
      GoRoute(path: Routes.teams, builder: (_, _) => const TeamsScreen()),
      GoRoute(
        path: Routes.teamEditor,
        builder: (_, state) =>
            TeamEditorScreen(team: state.extra as SavedTeam?),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [teamStoreProvider.overrideWithValue(store)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _toTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin equipos invita a crear el primero', (tester) async {
    await _pump(tester, MemoryTeamStore());
    expect(find.text('Crea tu primer equipo'), findsOneWidget);
    expect(find.text('Crear equipo'), findsOneWidget);
  });

  testWidgets('crear un equipo con color y emoji, sin jugadores (quedan '
      'como idea para más adelante)', (tester) async {
    final store = MemoryTeamStore();
    await _pump(tester, store);
    await tester.tap(find.text('Crear equipo'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo equipo'), findsOneWidget);

    // El nombre es obligatorio.
    await _tapVisible(tester, find.text('Crear equipo'));
    await _toTop(tester);
    expect(find.text('Escribe un nombre'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('nombre-equipo')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('nombre-equipo')),
      'Los Primos',
    );
    await _tapVisible(tester, find.text('🚀'));
    expect(find.textContaining('Jugadores', skipOffstage: false), findsNothing);
    await _tapVisible(tester, find.text('Crear equipo'));

    expect(find.text('Los Primos'), findsOneWidget);
    expect(find.text('0 partidas'), findsOneWidget);
    final team = store.teams.single;
    expect(team.name, 'Los Primos');
    expect(team.emoji, '🚀');
    expect(team.players, isEmpty);
  });

  testWidgets('no deja repetir el nombre de otro equipo', (tester) async {
    await _pump(
      tester,
      MemoryTeamStore(const [SavedTeam(id: 'a', name: 'Los Primos')]),
    );
    await tester.tap(find.text('Crear equipo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('nombre-equipo')),
      'los primos',
    );
    await _tapVisible(tester, find.text('Crear equipo'));
    await _toTop(tester);
    expect(find.text('Ya hay un equipo con ese nombre'), findsOneWidget);
  });

  testWidgets('editar y borrar con el botón de tres puntos o manteniendo '
      'presionado', (tester) async {
    final store = MemoryTeamStore(const [
      SavedTeam(id: 'a', name: 'Los Primos', played: 3, wins: 1, best: 12),
      SavedTeam(id: 'b', name: 'Los Tigres'),
    ]);
    await _pump(tester, store);
    expect(find.text('3 partidas'), findsOneWidget);
    expect(find.text('1 victoria'), findsOneWidget);
    expect(find.text('Mejor: 12'), findsOneWidget);

    await tester.longPress(find.text('Los Primos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar equipo'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('nombre-equipo')),
      'Los Primazos',
    );
    await _tapVisible(tester, find.text('Guardar cambios'));
    expect(find.text('Los Primazos'), findsOneWidget);
    // El historial se conserva al editar.
    expect(store.teams.first.played, 3);

    await tester.tap(find.byTooltip('Opciones').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Borrar "Los Tigres"?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();
    expect(find.text('Los Tigres'), findsNothing);
    expect(store.teams.map((t) => t.id), ['a']);
  });

  group('historial al terminar la partida', () {
    Future<ProviderContainer> play(List<int> hits) async {
      final store = MemoryTeamStore(const [
        SavedTeam(id: 'a', name: 'Los Primos', best: 1),
        SavedTeam(id: 'b', name: 'Los Tigres', best: 5),
      ]);
      final container = ProviderContainer(
        overrides: [teamStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final game = container.read(gameControllerProvider.notifier);
      game.configure(
        const GameConfig(
          groups: [
            Group('Los Primos', teamId: 'a'),
            Group('Los Tigres', teamId: 'b'),
            // Un equipo de la configuración aleatoria: no se guarda.
            Group('Los Lobos'),
          ],
          rounds: 1,
        ),
      );
      game.startWithDecks([
        for (var g = 0; g < 3; g++) [for (var i = 0; i < 5; i++) Word('$g$i')],
      ]);
      for (var g = 0; g < 3; g++) {
        game.finishTurn(
          Turn(
            round: 1,
            groupIndex: g,
            entries: [
              for (var i = 0; i < hits[g]; i++)
                TurnEntry(Word('$g$i'), WordOutcome.hit),
            ],
          ),
        );
      }
      game.endGame();
      await game.saveHistory();
      // Solo una vez, aunque se vuelva a llamar.
      await game.saveHistory();
      return container;
    }

    test(
      'suma la partida, la victoria del ganador y el mejor puntaje',
      () async {
        final container = await play([3, 2, 0]);
        final teams = await container.read(teamsProvider.future);
        final primos = teams.firstWhere((t) => t.id == 'a');
        final tigres = teams.firstWhere((t) => t.id == 'b');
        expect(primos.played, 1);
        expect(primos.wins, 1);
        expect(primos.best, 3);
        expect(tigres.played, 1);
        expect(tigres.wins, 0);
        // No superó su mejor puntaje.
        expect(tigres.best, 5);
        expect(teams, hasLength(2));
      },
    );

    test('en empate no cuenta victoria para nadie', () async {
      final container = await play([2, 2, 0]);
      final teams = await container.read(teamsProvider.future);
      expect(teams.every((t) => t.played == 1), isTrue);
      expect(teams.every((t) => t.wins == 0), isTrue);
    });
  });
}
