import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/screens/word_entry_screen.dart';
import 'package:charadeando_app/router.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el ojo muestra y oculta cada palabra', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(gameControllerProvider.notifier)
        .configure(const GameConfig(groups: [Group('A'), Group('B')]));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WordEntryScreen()),
      ),
    );
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'El Rey León');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('El Rey León'), findsNothing);

    await tester.tap(find.byTooltip('Mostrar'));
    await tester.pump();
    expect(find.text('1. El Rey León'), findsOneWidget);

    await tester.tap(find.byTooltip('Ocultar'));
    await tester.pump();
    expect(find.textContaining('El Rey León'), findsNothing);
  });

  testWidgets('rellena las palabras de prueba que faltan', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(gameControllerProvider.notifier)
        .configure(
          const GameConfig(groups: [Group('A'), Group('B')], wordsPerGroup: 12),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WordEntryScreen()),
      ),
    );
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rellenar palabras de prueba'));
    await tester.pump();

    expect(find.text('12 de 12 palabras'), findsOneWidget);
    expect(find.text('Rellenar palabras de prueba'), findsNothing);
  });

  testWidgets('sin grupos se escribe una sola lista de al menos 10', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(gameControllerProvider.notifier)
        .configure(const GameConfig(groups: [Group('')], inGroups: false));
    final router = GoRouter(
      initialLocation: Routes.words,
      routes: [
        GoRoute(path: Routes.words, builder: (_, _) => const WordEntryScreen()),
        GoRoute(path: Routes.turn, builder: (_, _) => const Text('Turno')),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // No hay pantalla para pasar el celular a otro grupo.
    expect(find.text('Empezar'), findsNothing);
    expect(find.text('Palabras'), findsOneWidget);
    for (var i = 0; i < 9; i++) {
      await tester.enterText(find.byType(TextField), 'Palabra $i');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }
    expect(find.text('9 palabras · mínimo 10'), findsOneWidget);
    final done = find.widgetWithText(FilledButton, 'Listo');
    expect(tester.widget<FilledButton>(done).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Palabra 9');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(find.text('Turno'), findsOneWidget);
    final game = container.read(gameControllerProvider);
    expect(game.decks.single, hasLength(10));
    expect(game.turnTitle, '¡A jugar!');
  });
}
