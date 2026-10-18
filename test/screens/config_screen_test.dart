import 'dart:async';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/config_screen.dart';
import 'package:charadeando_app/screens/team_editor_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:charadeando_app/widgets/category_art.dart';
import 'package:charadeando_app/widgets/config_section.dart';
import 'package:charadeando_app/widgets/number_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Equipos guardados en memoria, sin archivos.
class MemoryTeamStore extends TeamStore {
  MemoryTeamStore([this.teams = const []]);

  List<SavedTeam> teams;

  @override
  Future<List<SavedTeam>> load() async => teams;

  @override
  Future<void> save(List<SavedTeam> teams) async => this.teams = teams;
}

/// Equipos guardados para las pruebas.
const savedTeams = [
  SavedTeam(id: 't1', name: 'Los Primos', colorIndex: 0),
  SavedTeam(id: 't2', name: 'Los Abuelos', colorIndex: 3),
  SavedTeam(id: 't3', name: 'Las Tías', colorIndex: 5),
  SavedTeam(id: 't4', name: 'Los Vecinos', colorIndex: 7),
  SavedTeam(id: 't5', name: 'La Oficina', colorIndex: 9),
];

/// Toca un equipo de la sección Equipos de la configuración.
Future<void> tapTeam(WidgetTester tester, String name) async {
  // Desde arriba de la lista: los equipos van al principio.
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
  await tester.pumpAndSettle();
  final team = find.text(name);
  await tester.scrollUntilVisible(
    team,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(team);
  await tester.pumpAndSettle();
  await tester.tap(team);
  await tester.pump();
}

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
  TeamStore? teams,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      tvConnectedProvider.overrideWith((ref) => tv ?? Stream.value(false)),
      configStoreProvider.overrideWithValue(store ?? MemoryConfigStore()),
      teamStoreProvider.overrideWithValue(teams ?? MemoryTeamStore()),
      ...overrides,
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
        path: Routes.teamEditor,
        builder: (_, _) => const TeamEditorScreen(),
      ),
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
  testWidgets('la configuración aleatoria pone equipos al azar que no se '
      'guardan, y los cambia en cada toque', (tester) async {
    final teams = MemoryTeamStore();
    final container = await pumpConfig(tester, teams: teams);
    await tester.tap(find.text('Configuración aleatoria'));
    await tester.pump();
    List<String> chosen() => [
      for (final n in AutoFill.groupNames)
        if (find.text(n).evaluate().isNotEmpty) n,
    ];
    final first = chosen();
    expect(first, hasLength(2));
    expect(find.text('Solo esta partida'), findsNWidgets(2));

    await tester.tap(find.text('Configuración aleatoria'));
    await tester.pump();
    final second = chosen();
    expect(second, hasLength(2));
    expect(second.any(first.contains), isFalse);

    await tapContinue(tester);
    expect(find.text('Palabras'), findsOneWidget);
    final config = container.read(gameControllerProvider).config;
    expect(config.groups.map((g) => g.name).toSet(), second.toSet());
    expect(config.groups.every((g) => g.teamId == null), isTrue);
    // No se guardaron en Equipos.
    expect(teams.teams, isEmpty);
  });

  testWidgets('no continúa sin elegir al menos 2 equipos', (tester) async {
    await pumpConfig(tester, teams: MemoryTeamStore(savedTeams));
    await tapTeam(tester, 'Los Primos');
    await tapContinue(tester);

    expect(find.text('Palabras'), findsNothing);
    expect(find.text('Elijan de 2 a 4 equipos.'), findsWidgets);
  });

  testWidgets('sin equipos guardados se pueden crear ahí mismo y vuelven '
      'marcados', (tester) async {
    final container = await pumpConfig(tester);
    await tester.pumpAndSettle();
    expect(find.text('Creen sus equipos para jugar.'), findsOneWidget);
    final add = find.text('Nuevo equipo');
    for (final name in ['Los Primos', 'Los Tigres']) {
      await tester.scrollUntilVisible(
        add,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('nombre-equipo')), name);
      final create = find.text('Crear equipo');
      await tester.scrollUntilVisible(
        create,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(create);
      await tester.pumpAndSettle();
    }
    await tapContinue(tester);
    expect(find.text('Palabras'), findsOneWidget);
    final groups = container.read(gameControllerProvider).config.groups;
    expect(groups.map((g) => g.name), ['Los Primos', 'Los Tigres']);
    expect(groups.every((g) => g.teamId != null), isTrue);
  });

  testWidgets('recuerda escribir más palabras, sin cálculos', (tester) async {
    await pumpConfig(tester);
    await tester.scrollUntilVisible(
      find.textContaining('Más rondas = más palabras'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Más rondas = más palabras'), findsOneWidget);
  });

  testWidgets('se eligen hasta 4 equipos guardados, en el orden en que se '
      'tocan', (tester) async {
    final container = await pumpConfig(
      tester,
      teams: MemoryTeamStore(savedTeams),
    );
    await tester.pumpAndSettle();
    for (final t in ['Los Abuelos', 'Los Primos', 'Las Tías', 'Los Vecinos']) {
      await tapTeam(tester, t);
    }
    await tapTeam(tester, 'La Oficina');
    expect(find.text('Máximo 4 equipos.'), findsOneWidget);
    // Se cierra el aviso para que no tape el botón.
    ScaffoldMessenger.of(tester.element(find.byType(ConfigScreen)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();

    await tapContinue(tester);
    final groups = container.read(gameControllerProvider).config.groups;
    expect(groups.map((g) => g.name), [
      'Los Abuelos',
      'Los Primos',
      'Las Tías',
      'Los Vecinos',
    ]);
    expect(groups.map((g) => g.teamId), ['t2', 't1', 't3', 't4']);
  });

  testWidgets('con palabras automáticas solo se eligen las rondas y el '
      'tiempo', (tester) async {
    final container = await pumpConfig(
      tester,
      config: const GameConfig(wordSource: WordSource.random),
      teams: MemoryTeamStore(savedTeams),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Más rondas = más palabras'), findsNothing);
    expect(find.text('Duración del juego'), findsNothing);
    await tapTeam(tester, 'Los Primos');
    await tapTeam(tester, 'Los Abuelos');
    final rounds = find.ancestor(
      of: find.text('Rondas'),
      matching: find.byType(ConfigRow),
    );
    await tester.scrollUntilVisible(
      rounds,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(rounds, findsOneWidget);
    expect(find.text('Palabras por equipo'), findsNothing);
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
    await tester.pump();
    // Cómo se marcan los aciertos ya no se elige aquí, sino en Ajustes.
    expect(find.text('Movimiento'), findsNothing);

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
    final mixed = find.widgetWithText(ChoiceChip, 'Mezcladas');
    await tester.scrollUntilVisible(
      mixed,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<ChoiceChip>(mixed).selected, isTrue);
  });

  testWidgets('vienen marcadas Por frase y el video; solo faltan los '
      'equipos', (tester) async {
    final container = await pumpConfig(
      tester,
      config: const GameConfig(wordSource: WordSource.random),
      teams: MemoryTeamStore(savedTeams),
    );
    await tester.pumpAndSettle();
    await tapContinue(tester);
    expect(find.text('Elijan de 2 a 4 equipos.'), findsWidgets);
    // Se espera a que el aviso se cierre para que no tape el botón.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tapTeam(tester, 'Los Primos');
    await tapTeam(tester, 'Los Abuelos');
    await tapContinue(tester);
    expect(find.text('Descargando'), findsOneWidget);
    final config = container.read(gameControllerProvider).config;
    expect(config.scoringMode, ScoringMode.perPhrase);
    expect(config.hitMode, HitMode.tilt);
    expect(config.difficulty, Difficulty.mixed);
    expect(config.resolution, VideoResolution.hd);
  });

  testWidgets('guarda la configuración y la próxima vez aparece llena, con '
      'los mismos equipos', (tester) async {
    final store = MemoryConfigStore();
    final teams = MemoryTeamStore(savedTeams);
    await pumpConfig(
      tester,
      config: const GameConfig(wordSource: WordSource.random),
      store: store,
      teams: teams,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configuración aleatoria'));
    await tester.pump();
    // Se cambian los equipos al azar por dos guardados.
    for (final n in AutoFill.groupNames) {
      if (find.text(n).evaluate().isNotEmpty) await tapTeam(tester, n);
    }
    await tapTeam(tester, 'Las Tías');
    await tapTeam(tester, 'Los Primos');
    await tapContinue(tester);
    final saved = store.saved!;
    expect(saved.teamIds, ['t3', 't1']);

    // Una partida nueva: los equipos y las opciones vienen de la guardada.
    await tester.pumpWidget(const SizedBox());
    final container = await pumpConfig(
      tester,
      config: const GameConfig(wordSource: WordSource.random),
      store: store,
      teams: teams,
    );
    await tester.pumpAndSettle();
    await tapContinue(tester);
    final config = container.read(gameControllerProvider).config;
    expect(config.groups.map((g) => g.teamId), ['t3', 't1']);
    expect(config.rounds, saved.rounds);
    expect(config.turnDuration, saved.turnDuration);
    expect(config.scoringMode, saved.scoringMode);
    expect(config.difficulty, saved.difficulty);
  });

  testWidgets('al duplicar la pantalla se activa el Modo TV y se oculta '
      'el video', (tester) async {
    final tv = StreamController<bool>();
    addTearDown(tv.close);
    final container = await pumpConfig(tester, tv: tv.stream);
    tv.add(false);
    await tester.tap(find.text('Configuración aleatoria'));
    await tester.pump();

    final connect = find.text('¿Cómo conectar un TV?');
    await tester.scrollUntilVisible(
      connect,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Jugar en un TV'), findsOneWidget);
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
    expect(find.text('Resolución'), findsNothing);
    // Se espera a que el aviso se cierre para que no tape el botón.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tapContinue(tester);
    expect(find.text('Palabras'), findsOneWidget);
    expect(container.read(gameControllerProvider).config.tvMode, isTrue);
  });

  testWidgets('"¿Cómo conectar un TV?" muestra los pasos numerados', (
    tester,
  ) async {
    final tv = StreamController<bool>();
    addTearDown(tv.close);
    await pumpConfig(tester, tv: tv.stream);
    tv.add(false);
    final connect = find.text('¿Cómo conectar un TV?');
    await tester.scrollUntilVisible(
      connect,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(connect);
    await tester.pumpAndSettle();
    expect(find.text('Conectar a un televisor'), findsOneWidget);
    expect(find.text('Baja los ajustes rápidos'), findsOneWidget);
    expect(find.text('Elige tu televisor'), findsOneWidget);
    expect(find.text('También sirve un cable HDMI'), findsOneWidget);
    // Avisa que si el TV ya duplica la pantalla, la app lo detecta sola…
    expect(
      find.text('¿Ya duplicas la pantalla? Se conecta solo.'),
      findsOneWidget,
    );
    // …y si se conecta con la ventana abierta, lo muestra ahí mismo.
    tv.add(true);
    await tester.pumpAndSettle();
    expect(find.text('¡TV conectado!'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(find.text('Conectar a un televisor'), findsNothing);
  });

  testWidgets('al desconectar el TV vuelve el video', (tester) async {
    final tv = StreamController<bool>();
    addTearDown(tv.close);
    await pumpConfig(tester, tv: tv.stream);
    tv.add(true);
    await tester.pumpAndSettle();
    expect(find.text('Resolución'), findsNothing);

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
    expect(find.text('Resolución'), findsOneWidget);
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
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Difícil'))
          .selected,
      isTrue,
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

  testWidgets('en Fotomímica no se ve la Puntuación, se juega por frase y '
      'como mucho 5 rondas', (tester) async {
    final container = await pumpConfig(
      tester,
      config: const GameConfig(
        // Viene de una partida de 8 rondas.
        rounds: 8,
        wordSource: WordSource.random,
        groups: [Group('A'), Group('B')],
        category: GameCategory.photoMime,
      ),
      // Aunque la última partida fuera por palabra.
      store: MemoryConfigStore(
        const SavedConfig(
          groupNames: ['A', 'B'],
          rounds: 3,
          turnDuration: Duration(seconds: 60),
          wordsPerGroup: 10,
          scoringMode: ScoringMode.perWord,
          hitMode: HitMode.tilt,
          resolution: VideoResolution.hd,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Continuar'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Puntuación'), findsNothing);
    expect(find.text('Cómo se cuentan los puntos'), findsNothing);
    final rounds = tester.widget<NumberStepper>(
      find.descendant(
        of: find.widgetWithText(ConfigRow, 'Rondas'),
        matching: find.byType(NumberStepper),
      ),
    );
    expect((rounds.value, rounds.max), (5, 5));
    await tapContinue(tester);
    expect(find.text('Descargando'), findsOneWidget);
    final config = container.read(gameControllerProvider).config;
    expect(config.photoMime, isTrue);
    expect(config.scoringMode, ScoringMode.perPhrase);
    expect(config.rounds, GameConfig.maxPhotoMimeRounds);
  });

  testWidgets('sin equipos no se ven Equipos ni Palabras por equipo', (
    tester,
  ) async {
    final container = await pumpConfig(
      tester,
      config: const GameConfig(inGroups: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Equipos'), findsNothing);
    expect(find.text('Palabras por equipo'), findsNothing);

    // No pide nombres: sigue directo a escribir las palabras.
    await tapContinue(tester);
    expect(find.text('Palabras'), findsOneWidget);
    final config = container.read(gameControllerProvider).config;
    expect(config.inGroups, isFalse);
    expect(config.groupCount, 1);
  });

  testWidgets('lo primero es elegir sin equipos o en equipos', (tester) async {
    await pumpConfig(
      tester,
      config: const GameConfig(
        category: GameCategory.animals,
        wordSource: WordSource.random,
        inGroups: false,
      ),
    );
    await tester.pumpAndSettle();
    // Sin equipos viene marcado.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Sin equipos'),
          matching: find.byType(Row),
        ),
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
    );
    expect(find.text('Equipos'), findsNothing);
    // Va antes que todo lo demás.
    expect(
      tester.getTopLeft(find.text('Sin equipos')).dy,
      lessThan(tester.getTopLeft(find.text('Configuración aleatoria')).dy),
    );

    await tester.tap(find.text('En equipos'));
    await tester.pumpAndSettle();
    expect(find.text('Equipos'), findsOneWidget);
  });

  testWidgets('arriba muestra el dibujo y el nombre de la categoría', (
    tester,
  ) async {
    await pumpConfig(
      tester,
      config: const GameConfig(
        category: GameCategory.movies,
        wordSource: WordSource.random,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CategoryArt), findsOneWidget);
    expect(
      tester.widget<CategoryArt>(find.byType(CategoryArt)).category,
      GameCategory.movies,
    );
    expect(find.text('Películas'), findsOneWidget);
  });
}
