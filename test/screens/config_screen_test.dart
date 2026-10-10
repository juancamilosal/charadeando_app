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
      GoRoute(
        path: Routes.autoWords,
        builder: (_, _) => const Text('Descargando'),
      ),
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

  testWidgets('recuerda escribir más palabras, sin cálculos', (tester) async {
    await pumpConfig(tester);
    expect(
      find.textContaining('Recuerda: mientras más rondas'),
      findsOneWidget,
    );
  });

  testWidgets('no deja pasar de 6 grupos', (tester) async {
    await pumpConfig(tester);
    final add = find.byIcon(Icons.add).first;
    for (var i = 0; i < 6; i++) {
      await tester.tap(add);
      await tester.pump();
    }
    expect(find.textContaining('Nombre del grupo'), findsNWidgets(6));
  });

  testWidgets('con palabras automáticas no pide escribirlas', (tester) async {
    await pumpConfig(
      tester,
      config: const GameConfig(wordSource: WordSource.random),
    );
    expect(
      find.textContaining('Nosotros ponemos las palabras'),
      findsOneWidget,
    );
    expect(find.textContaining('Recuerda: mientras más rondas'), findsNothing);

    await tester.tap(find.text('Rellenar datos de prueba'));
    await tester.pump();
    await tapContinue(tester);
    expect(find.text('Descargando'), findsOneWidget);
  });
}
