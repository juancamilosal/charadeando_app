import 'dart:async';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/turn_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Deja pasar la cuenta regresiva de 3 segundos.
Future<void> countdown(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('en Modo TV el juez marca con botones y el turno se pausa si '
      'se desconecta el televisor', (tester) async {
    // Sin celular de verdad: girar la pantalla no hace nada.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);

    final tv = StreamController<bool>();
    addTearDown(tv.close);
    final container = ProviderContainer(
      overrides: [tvConnectedProvider.overrideWith((ref) => tv.stream)],
    );
    addTearDown(container.dispose);
    final game = container.read(gameControllerProvider.notifier);
    game.configure(
      const GameConfig(
        groups: [Group('Tigres'), Group('Águilas')],
        hitMode: HitMode.tv,
        scoringMode: ScoringMode.perPhrase,
      ),
    );
    game.startWithDecks([
      [Word('Pizza'), Word('Jirafa')],
      [Word('Titanic')],
    ]);

    final router = GoRouter(
      initialLocation: Routes.turn,
      routes: [
        GoRoute(path: Routes.turn, builder: (_, _) => const TurnScreen()),
        GoRoute(
          path: Routes.turnResult,
          builder: (_, _) => const Text('Resultados'),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    tv.add(false);
    await tester.pumpAndSettle();
    expect(
      find.text('Conecten el televisor para empezar el turno.'),
      findsOneWidget,
    );
    await tester.tap(find.text('¡Listo!'));
    await tester.pump();
    expect(find.text('3'), findsNothing);

    tv.add(true);
    await tester.pumpAndSettle();
    expect(find.text('El TV ya está conectado a este celular'), findsOneWidget);

    await tester.tap(find.text('¡Listo!'));
    await countdown(tester);
    expect(find.text('Pizza'), findsOneWidget);
    expect(find.text('Tigres  0'), findsOneWidget);

    await tester.tap(find.text('¡Correcto!'));
    await tester.pump();
    expect(find.text('Tigres  1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.text('Jirafa'), findsOneWidget);

    tv.add(false);
    await tester.pumpAndSettle();
    expect(find.text('Se desconectó el televisor'), findsOneWidget);
    expect(find.text('Esperando el televisor…'), findsOneWidget);

    tv.add(true);
    await countdown(tester);
    expect(find.text('Jirafa'), findsOneWidget);

    await tester.tap(find.text('Pasar'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Resultados'), findsOneWidget);
    final turn = container.read(gameControllerProvider).lastTurn!;
    expect(turn.hits.map((w) => w.text), ['Pizza']);
    expect(turn.passed.map((w) => w.text), ['Jirafa']);
  });
}
