import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/config_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<ProviderContainer> pumpConfig(
  WidgetTester tester, {
  GameConfig? config,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  if (config != null) {
    container.read(gameControllerProvider.notifier).configure(config);
  }
  final router = GoRouter(
    initialLocation: Routes.config,
    routes: [
      GoRoute(path: Routes.config, builder: (_, _) => const ConfigScreen()),
      GoRoute(path: Routes.words, builder: (_, _) => const Text('Palabras')),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  return container;
}

Future<void> tapContinue(WidgetTester tester) async {
  final button = find.text('Continuar');
  await tester.scrollUntilVisible(
    button,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rellena la configuración con los datos de prueba', (
    tester,
  ) async {
    final container = await pumpConfig(tester);
    await tester.tap(find.text('Rellenar datos de prueba'));
    await tester.pump();
    await tapContinue(tester);

    expect(find.text('Palabras'), findsOneWidget);
    final config = container.read(gameControllerProvider).config;
    final expected = TestData.config;
    expect(
      config.groups.map((g) => g.name),
      expected.groups.map((g) => g.name),
    );
    expect(config.rounds, expected.rounds);
    expect(config.turnDuration, expected.turnDuration);
    expect(config.wordsPerGroup, expected.wordsPerGroup);
  });

  testWidgets('no continúa si falta el nombre de algún grupo', (tester) async {
    await pumpConfig(tester);
    await tapContinue(tester);

    expect(find.text('Palabras'), findsNothing);
    expect(find.text('Escriban el nombre de cada grupo.'), findsOneWidget);
  });

  testWidgets('advierte cuando las palabras no alcanzan', (tester) async {
    // Por defecto: 3 rondas de 60 s piden unas 30 palabras y son 10.
    await pumpConfig(tester);
    expect(find.textContaining('pierde sus turnos'), findsOneWidget);
  });

  testWidgets('no advierte si las palabras alcanzan', (tester) async {
    // 1 ronda de 60 s pide unas 10 palabras.
    await pumpConfig(
      tester,
      config: const GameConfig(rounds: 1, wordsPerGroup: 10),
    );
    expect(find.textContaining('pierde sus turnos'), findsNothing);
  });
}
