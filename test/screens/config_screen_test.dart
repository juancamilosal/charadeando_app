import 'dart:async';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/config_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:charadeando_app/widgets/config_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Configuración guardada en memoria, sin archivos.
class MemoryConfigStore extends ConfigStore {
  MemoryConfigStore([this.saved]);

  SavedConfig? saved;

  @override
  Future<SavedConfig?> load() async => saved;

  @override
  Future<void> save(SavedConfig config) async => saved = config;
}

Future<ProviderContainer> pumpConfig(
  WidgetTester tester, {
  GameConfig? config,
  Stream<bool>? tv,
  ConfigStore? store,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      tvConnectedProvider.overrideWith((ref) => tv ?? Stream.value(false)),
      configStoreProvider.overrideWithValue(store ?? MemoryConfigStore()),
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
    await tester.tap(find.text('Configuración aleatoria'));
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
    await tester.tap(find.text('Configuración aleatoria'));
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

  testWidgets('no deja pasar de 4 grupos', (tester) async {
    await pumpConfig(tester);
    final add = find.byIcon(Icons.add).first;
    for (var i = 0; i < 4; i++) {
      await tester.tap(add);
      await tester.pump();
    }
    expect(find.textContaining('Nombre del grupo'), findsNWidgets(4));
  });

  testWidgets('con palabras automáticas solo se eligen las rondas y el '
      'tiempo', (tester) async {
    final container = await pumpConfig(
      tester,
      config: const GameConfig(wordSource: WordSource.random),
    );
    expect(find.textContaining('Recuerda: mientras más rondas'), findsNothing);
    expect(find.text('Duración del juego'), findsNothing);
    for (var i = 0; i < 2; i++) {
      await tester.enterText(find.byType(TextField).at(i), 'G$i');
    }
    final rounds = find.ancestor(
      of: find.text('Rondas'),
      matching: find.byType(ConfigRow),
    );
    await tester.scrollUntilVisible(
      rounds,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Cada turno dura hasta que se acabe el tiempo.'),
      findsOneWidget,
    );
    expect(find.text('Palabras por grupo'), findsNothing);
    final more = find.descendant(of: rounds, matching: find.byIcon(Icons.add));
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pump();

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
    expect(config.rounds, 4);
    expect(config.difficulty, Difficulty.mixed);
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

  testWidgets('vienen marcadas Por frase, Movimiento y el video; solo '
      'faltan los nombres', (tester) async {
    final container = await pumpConfig(
      tester,
      config: const GameConfig(wordSource: WordSource.random),
    );
    await tapContinue(tester);
    expect(find.text('Escriban el nombre de cada grupo.'), findsOneWidget);
    // Se espera a que el aviso se cierre para que no tape el botón.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Configuración aleatoria'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField).at(0), 'A');
    await tester.enterText(find.byType(TextField).at(1), 'B');
    await tapContinue(tester);
    expect(find.text('Descargando'), findsOneWidget);
    final config = container.read(gameControllerProvider).config;
    expect(config.scoringMode, ScoringMode.perPhrase);
    expect(config.hitMode, HitMode.tilt);
    expect(config.difficulty, Difficulty.mixed);
    expect(config.resolution, VideoResolution.hd);
  });

  testWidgets('guarda la configuración y la próxima vez aparece llena', (
    tester,
  ) async {
    final store = MemoryConfigStore();
    await pumpConfig(
      tester,
      config: const GameConfig(wordSource: WordSource.random),
      store: store,
    );
    await tester.tap(find.text('Configuración aleatoria'));
    await tester.pump();
    await tapContinue(tester);
    final saved = store.saved!;
    expect(saved.groupNames, hasLength(2));

    // Una partida nueva: los nombres y las opciones vienen de la guardada.
    await tester.pumpWidget(const SizedBox());
    final container = await pumpConfig(
      tester,
      config: const GameConfig(wordSource: WordSource.random),
      store: store,
    );
    await tester.pumpAndSettle();
    final names = [
      for (final f in tester.widgetList<TextField>(find.byType(TextField)))
        f.controller!.text,
    ];
    expect(names, saved.groupNames);
    await tapContinue(tester);
    final config = container.read(gameControllerProvider).config;
    expect(config.rounds, saved.rounds);
    expect(config.turnDuration, saved.turnDuration);
    expect(config.scoringMode, saved.scoringMode);
    expect(config.difficulty, saved.difficulty);
  });

  testWidgets('al duplicar la pantalla se activa el Modo TV y se ocultan '
      'los aciertos y el video', (tester) async {
    final tv = StreamController<bool>();
    addTearDown(tv.close);
    final container = await pumpConfig(tester, tv: tv.stream);
    tv.add(false);
    await tester.tap(find.text('Configuración aleatoria'));
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
    await tester.tap(find.text('Configuración aleatoria'));
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

  testWidgets('con una categoría propia no se pide dificultad', (tester) async {
    final container = await pumpConfig(
      tester,
      config: GameConfig(
        wordSource: WordSource.random,
        groups: const [Group('A'), Group('B')],
        customCategory: CustomCategory(
          id: 'f1',
          name: 'Mi familia',
          words: [for (var i = 0; i < 10; i++) 'P$i'],
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Partida: Mi familia'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Partida: Mi familia'), findsOneWidget);
    expect(find.text('Dificultad'), findsNothing);
    await tapContinue(tester);
    expect(find.text('Descargando'), findsOneWidget);
    final config = container.read(gameControllerProvider).config;
    expect(config.difficulty, isNull);
    expect(config.customCategory?.name, 'Mi familia');
  });

  testWidgets('sin grupos no se ven Grupos ni Palabras por grupo', (
    tester,
  ) async {
    final container = await pumpConfig(
      tester,
      config: const GameConfig(inGroups: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Grupos'), findsNothing);
    expect(find.text('Palabras por grupo'), findsNothing);
    expect(find.text('Un turno por ronda.'), findsOneWidget);

    // No pide nombres: sigue directo a escribir las palabras.
    await tapContinue(tester);
    expect(find.text('Palabras'), findsOneWidget);
    final config = container.read(gameControllerProvider).config;
    expect(config.inGroups, isFalse);
    expect(config.groupCount, 1);
  });
}
