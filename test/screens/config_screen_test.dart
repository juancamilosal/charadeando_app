import 'dart:async';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/config_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:charadeando_app/widgets/config_section.dart';
import 'package:charadeando_app/widgets/number_stepper.dart';
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
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('llena la configuración automáticamente y la cambia en cada '
      'toque', (tester) async {
    final container = await pumpConfig(tester);
    await tester.tap(find.text('Llenar automáticamente'));
    await tester.pump();
    List<String> names() => [
      for (final f in tester.widgetList<TextField>(find.byType(TextField)))
        f.controller!.text,
    ];
    final first = names();
    expect(first, hasLength(2));
    expect(first.every(AutoFill.groupNames.contains), isTrue);

    // Al agregar un grupo y volver a tocar, el juego también lo nombra.
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    await tester.tap(find.text('Llenar automáticamente'));
    await tester.pump();
    final second = names();
    expect(second, hasLength(3));
    expect(second.toSet(), hasLength(3));
    expect(second.any(first.contains), isFalse);

    await tapContinue(tester);
    expect(find.text('Palabras'), findsOneWidget);
    final config = container.read(gameControllerProvider).config;
    expect(config.groups.map((g) => g.name), second);
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

  testWidgets('con palabras automáticas se juega por rondas, o eligiendo '
      'las palabras por ronda', (tester) async {
    final container = await pumpConfig(
      tester,
      config: const GameConfig(wordSource: WordSource.random),
    );
    expect(find.textContaining('Recuerda: mientras más rondas'), findsNothing);
    expect(find.text('Duración del juego'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tester.enterText(find.byType(TextField).at(i), 'G$i');
    }
    // Por número de rondas viene elegida: el juego calcula las palabras,
    // una cada 5 segundos.
    await tester.scrollUntilVisible(
      find.text('Cada turno tendrá 12 palabras.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cada turno tendrá 12 palabras.'), findsOneWidget);
    expect(find.text('Palabras por grupo'), findsNothing);

    // Con más tiempo, las palabras suben solas.
    final time = find.ancestor(
      of: find.text('Tiempo por turno'),
      matching: find.byType(ConfigRow),
    );
    final longer = find.descendant(of: time, matching: find.byIcon(Icons.add));
    await tester.ensureVisible(longer);
    await tester.pumpAndSettle();
    await tester.tap(longer);
    await tester.pump();
    expect(find.text('Cada turno tendrá 15 palabras.'), findsOneWidget);

    final perRound = find.text('Palabras por ronda');
    await tester.scrollUntilVisible(
      perRound,
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(perRound);
    await tester.pump();
    final row = find.ancestor(
      of: find.text('Palabras por grupo'),
      matching: find.byType(ConfigRow),
    );
    int words() => tester
        .widget<NumberStepper>(
          find.descendant(of: row, matching: find.byType(NumberStepper)),
        )
        .value;
    expect(words(), 15);
    final more = find.descendant(of: row, matching: find.byIcon(Icons.add));
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pump();
    expect(words(), 16);

    // Faltan la puntuación y los aciertos.
    final perPhrase = find.text('Por frase');
    await tester.scrollUntilVisible(
      perPhrase,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(perPhrase);
    await tester.pumpAndSettle();
    await tester.tap(perPhrase);
    final tilt = find.text('Movimiento');
    await tester.scrollUntilVisible(
      tilt,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(tilt);
    await tester.pumpAndSettle();
    await tester.tap(tilt);
    await tester.pump();

    await tapContinue(tester);
    expect(find.text('Descargando'), findsOneWidget);
    final config = container.read(gameControllerProvider).config;
    expect(config.wordSource, WordSource.random);
    expect(config.wordsPerTurn, 16);
    expect(config.difficulty, Difficulty.mixed);
  });

  testWidgets('con 6 grupos y 10 rondas avisa que la base pone el máximo', (
    tester,
  ) async {
    await pumpConfig(
      tester,
      config: GameConfig(
        wordSource: WordSource.random,
        rounds: 10,
        groups: List.filled(6, const Group('')),
      ),
    );
    final perRound = find.text('Palabras por ronda');
    await tester.scrollUntilVisible(
      perRound,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(perRound);
    await tester.pumpAndSettle();
    await tester.tap(perRound);
    await tester.pump();
    final note = find.text('Máximo 5 por grupo para no repetir palabras.');
    await tester.scrollUntilVisible(
      note,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(note, findsOneWidget);
  });

  testWidgets('las palabras vienen mezcladas por defecto', (tester) async {
    await pumpConfig(
      tester,
      config: const GameConfig(wordSource: WordSource.random),
    );
    final mixed = find.text(
      'Fáciles, normales y difíciles: el doble de variedad.',
    );
    await tester.scrollUntilVisible(
      mixed,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(mixed, findsOneWidget);
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
      find.text('Elijan la puntuación y cómo se marcan los aciertos.'),
      findsOneWidget,
    );
    final noVideo = find.text('Jugar sin grabar');
    await tester.scrollUntilVisible(
      noVideo,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(noVideo, findsOneWidget);
  });

  testWidgets('al duplicar la pantalla se activa el Modo TV y se ocultan '
      'los aciertos y el video', (tester) async {
    final tv = StreamController<bool>();
    addTearDown(tv.close);
    final container = await pumpConfig(tester, tv: tv.stream);
    tv.add(false);
    await tester.tap(find.text('Llenar automáticamente'));
    await tester.pump();

    final connect = find.text('Conectar las palabras a un televisor');
    await tester.scrollUntilVisible(
      connect,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Ningún TV conectado todavía'), findsOneWidget);
    // El Modo TV va al final, después del video.
    expect(find.text('Resolución'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Modo TV')).dy,
      greaterThan(tester.getTopLeft(find.text('Resolución')).dy),
    );

    tv.add(true);
    await tester.pumpAndSettle();
    expect(find.text('Desconectar TV'), findsOneWidget);
    expect(find.textContaining('Modo TV activado'), findsWidgets);
    expect(find.text('Cómo se marcan los aciertos'), findsNothing);
    expect(find.text('Resolución'), findsNothing);
    // Se espera a que el aviso se cierre para que no tape el botón.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tapContinue(tester);
    expect(find.text('Palabras'), findsOneWidget);
    expect(container.read(gameControllerProvider).config.tvMode, isTrue);
  });

  testWidgets('al desconectar el TV vuelven los aciertos y el video', (
    tester,
  ) async {
    final tv = StreamController<bool>();
    addTearDown(tv.close);
    await pumpConfig(tester, tv: tv.stream);
    tv.add(true);
    await tester.pumpAndSettle();
    expect(find.text('Cómo se marcan los aciertos'), findsNothing);

    tv.add(false);
    await tester.pumpAndSettle();
    expect(
      find.text('TV desconectado: se juega sin televisor'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Resolución'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cómo se marcan los aciertos'), findsOneWidget);
  });

  testWidgets('el Modo TV también está con palabras automáticas', (
    tester,
  ) async {
    await pumpConfig(
      tester,
      config: const GameConfig(wordSource: WordSource.random),
    );
    await tester.scrollUntilVisible(
      find.text('Modo TV'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Modo TV'), findsOneWidget);
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
    await tester.tap(find.text('Llenar automáticamente'));
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

  testWidgets('una categoría muestra su nombre en la partida', (tester) async {
    await pumpConfig(
      tester,
      config: const GameConfig(
        wordSource: WordSource.random,
        category: GameCategory.animals,
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Partida: Animales'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Partida: Animales'), findsOneWidget);
  });
}
