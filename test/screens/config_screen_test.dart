import 'dart:async';

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
  Stream<bool>? tv,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      tvConnectedProvider.overrideWith((ref) => tv ?? Stream.value(false)),
    ],
  );
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
    final container = await pumpConfig(
      tester,
      config: const GameConfig(wordSource: WordSource.random),
    );
    expect(
      find.textContaining('Nosotros ponemos las palabras'),
      findsOneWidget,
    );
    expect(find.text('Cada grupo tendrá 15 palabras.'), findsOneWidget);
    expect(find.textContaining('Recuerda: mientras más rondas'), findsNothing);

    await tester.tap(find.text('Rellenar datos de prueba'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add).at(1));
    await tester.pump();
    expect(find.text('35'), findsOneWidget);

    final untilEnd = find.text('Hasta que se acaben las palabras');
    await tester.scrollUntilVisible(
      untilEnd,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(untilEnd);
    await tester.pumpAndSettle();
    await tester.tap(untilEnd);
    await tester.pump();
    expect(find.text('Rondas'), findsNothing);

    await tapContinue(tester);
    expect(find.text('Descargando'), findsOneWidget);
    final config = container.read(gameControllerProvider).config;
    expect(config.wordSource, WordSource.random);
    expect(config.autoWordCount, 35);
    expect(config.gameEnd, GameEnd.wordsRunOut);
  });

  testWidgets('ninguna opción viene elegida, salvo el video', (tester) async {
    await pumpConfig(
      tester,
      config: const GameConfig(
        wordSource: WordSource.random,
        groups: [Group('A'), Group('B')],
      ),
    );
    await tapContinue(tester);

    expect(find.text('Descargando'), findsNothing);
    expect(
      find.text(
        'Elijan la dificultad, la duración del juego, la puntuación y cómo '
        'se marcan los aciertos.',
      ),
      findsOneWidget,
    );
    expect(find.text('Elijan una opción'), findsWidgets);

    final noVideo = find.text('Jugar sin grabar');
    await tester.scrollUntilVisible(
      noVideo,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(noVideo, findsOneWidget);
  });

  testWidgets('el Modo TV es una sección aparte y no deja seguir sin el '
      'televisor', (tester) async {
    final tv = StreamController<bool>();
    addTearDown(tv.close);
    final container = await pumpConfig(tester, tv: tv.stream);
    tv.add(false);
    await tester.tap(find.text('Rellenar datos de prueba'));
    await tester.pump();

    final withTv = find.text('Con televisor');
    await tester.scrollUntilVisible(
      withTv,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Cómo se marcan los aciertos'), findsOneWidget);
    expect(find.text('Resolución'), findsOneWidget);

    await tester.tap(withTv);
    await tester.pump();
    expect(
      find.textContaining('Duplica la pantalla de tu celular'),
      findsOneWidget,
    );
    expect(find.text('Cómo se marcan los aciertos'), findsNothing);
    expect(find.text('Resolución'), findsNothing);
    expect(find.text('Ningún TV conectado todavía'), findsOneWidget);

    await tapContinue(tester);
    expect(find.text('Palabras'), findsNothing);
    expect(
      find.text(
        'Conecten el televisor para continuar, o elijan jugar sin '
        'televisor.',
      ),
      findsOneWidget,
    );

    tv.add(true);
    await tester.pump();
    // El aviso anterior se cierra antes de mostrar el nuevo.
    await tester.pumpAndSettle();
    expect(
      find.text('El TV ya está conectado a este celular'),
      findsNWidgets(2),
    );
    // Se espera a que el aviso se cierre para que no tape el botón.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tapContinue(tester);
    expect(find.text('Palabras'), findsOneWidget);
    final config = container.read(gameControllerProvider).config;
    expect(config.hitMode, HitMode.tv);
    expect(config.tvMode, isTrue);
  });

  testWidgets('con palabras manuales hay que elegir si juegan con '
      'televisor', (tester) async {
    await pumpConfig(
      tester,
      config: const GameConfig(groups: [Group('A'), Group('B')]),
    );
    await tapContinue(tester);
    expect(
      find.text(
        'Elijan si juegan con el televisor, la puntuación y cómo se marcan '
        'los aciertos.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('con palabras automáticas no se ofrece el Modo TV', (
    tester,
  ) async {
    await pumpConfig(
      tester,
      config: const GameConfig(wordSource: WordSource.random),
    );
    final tilt = find.text('Movimiento');
    await tester.scrollUntilVisible(
      tilt,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Modo TV'), findsNothing);
  });

  testWidgets('con palabras automáticas hay que elegir la dificultad', (
    tester,
  ) async {
    final container = await pumpConfig(
      tester,
      config: const GameConfig(
        wordSource: WordSource.random,
        groups: [Group('A'), Group('B')],
      ),
    );
    await tester.tap(find.text('Rellenar datos de prueba'));
    await tester.pump();
    final hard = find.text('Difícil');
    await tester.scrollUntilVisible(
      hard,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(hard);
    await tester.pumpAndSettle();
    await tester.tap(hard);
    await tester.pump();
    expect(
      find.text('Poco conocidas, abstractas o emociones.'),
      findsOneWidget,
    );

    await tapContinue(tester);
    expect(find.text('Descargando'), findsOneWidget);
    expect(
      container.read(gameControllerProvider).config.difficulty,
      Difficulty.hard,
    );
  });

  testWidgets('con palabras manuales no se pide dificultad', (tester) async {
    await pumpConfig(tester);
    expect(find.text('Dificultad'), findsNothing);
  });

  testWidgets('una categoría muestra su nombre en las palabras', (
    tester,
  ) async {
    await pumpConfig(
      tester,
      config: const GameConfig(
        wordSource: WordSource.random,
        category: GameCategory.animals,
      ),
    );
    expect(find.text('Palabras: Animales'), findsOneWidget);
  });
}
