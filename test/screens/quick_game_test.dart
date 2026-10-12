import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/category_screen.dart';
import 'package:charadeando_app/screens/turn_result_screen.dart';
import 'package:charadeando_app/screens/word_entry_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'config_screen_test.dart' show MemoryConfigStore;

/// Sin carpeta de videos de verdad.
class _NoVideos extends VideoService {
  @override
  Future<void> deleteAll() async {}
}

const _saved = SavedConfig(
  groupNames: ['Tigres', 'Águilas'],
  rounds: 5,
  turnDuration: Duration(seconds: 90),
  wordsPerGroup: 15,
  scoringMode: ScoringMode.perWord,
  hitMode: HitMode.tilt,
  resolution: VideoResolution.off,
);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  String initial, {
  GameConfig? config,
  MemoryConfigStore? store,
  void Function(ProviderContainer)? setUp,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      tvConnectedProvider.overrideWith((ref) => Stream.value(false)),
      configStoreProvider.overrideWithValue(store ?? MemoryConfigStore()),
      videoServiceProvider.overrideWithValue(_NoVideos()),
    ],
  );
  addTearDown(container.dispose);
  if (config != null) {
    container.read(gameControllerProvider.notifier).configure(config);
  }
  setUp?.call(container);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: Routes.categories,
        builder: (_, _) => const CategoryScreen(),
      ),
      GoRoute(path: Routes.config, builder: (_, _) => const Text('Config')),
      GoRoute(
        path: Routes.autoWords,
        builder: (_, _) => const Text('Descargando'),
      ),
      GoRoute(path: Routes.words, builder: (_, _) => const WordEntryScreen()),
      GoRoute(path: Routes.turn, builder: (_, _) => const Text('Turno')),
      GoRoute(path: Routes.freeMode, builder: (_, _) => const Text('Libre')),
      GoRoute(
        path: Routes.turnResult,
        builder: (_, _) => const TurnResultScreen(),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  group('QuickGame.config', () {
    test('un solo turno de un minuto, sin grupos y con hasta 20 palabras', () {
      final config = QuickGame.config(
        const GameConfig(
          category: GameCategory.animals,
          wordSource: WordSource.random,
          rounds: 4,
          turnDuration: Duration(seconds: 90),
        ),
        saved: _saved,
      );
      expect(config.quick, isTrue);
      expect(config.inGroups, isFalse);
      expect(config.groupCount, 1);
      expect(config.turns, 1);
      expect(config.turnDuration, const Duration(seconds: 60));
      expect(config.difficulty, Difficulty.mixed);
      expect(config.hitMode, HitMode.tilt);
      expect(config.autoWordsNeeded, GameConfig.quickMaxWords);
      // La última configuración era "sin video": tampoco se graba.
      expect(config.records, isFalse);
    });

    test('con un TV conectado marca el juez, y sin configuración guardada '
        'graba en HD', () {
      final config = QuickGame.config(
        const GameConfig(wordSource: WordSource.random),
        tv: true,
      );
      expect(config.hitMode, HitMode.tv);
      expect(config.resolution, VideoResolution.hd);
    });

    test('nunca pide más de 20 palabras, aunque el turno sea largo', () {
      final config = QuickGame.config(
        const GameConfig(wordSource: WordSource.random),
      ).copyWith(turnDuration: const Duration(seconds: 90));
      expect(config.autoWordsNeeded, GameConfig.quickMaxWords);
    });

    test('la personalizada que sigue vuelve a la configuración de siempre', () {
      final quick = QuickGame.config(
        const GameConfig(category: GameCategory.movies),
      );
      final custom = QuickGame.custom(quick);
      expect(custom.quick, isFalse);
      expect(custom.category, GameCategory.movies);
      expect(custom.groupCount, 2);
      expect(custom.rounds, const GameConfig().rounds);
    });
  });

  testWidgets('"Partida rápida" se salta la configuración y no cambia la '
      'última guardada', (tester) async {
    final store = MemoryConfigStore(_saved);
    final container = await _pump(tester, Routes.categories, store: store);
    final food = find.text('Comida');
    await tester.scrollUntilVisible(
      food,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(food);
    await tester.pump();
    await tester.tap(food);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('1 minuto, sin configurar nada'), findsOneWidget);
    expect(find.text('Grupos, rondas, video y ruleta'), findsOneWidget);
    await tester.tap(find.text('Partida rápida'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Descargando'), findsOneWidget);
    expect(find.text('Config'), findsNothing);
    final config = container.read(gameControllerProvider).config;
    expect(config.quick, isTrue);
    expect(config.category, GameCategory.food);
    expect(config.resolution, VideoResolution.off);
    expect(store.saved, same(_saved));
  });

  group('palabras manuales de la partida rápida', () {
    final quick = QuickGame.config(
      const GameConfig(wordSource: WordSource.groups),
    );

    Future<void> add(WidgetTester tester, int count, {int from = 0}) async {
      for (var i = from; i < from + count; i++) {
        await tester.enterText(find.byType(TextField), 'Palabra $i');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
      }
    }

    bool canContinue(WidgetTester tester) =>
        tester
            .widget<ButtonStyleButton>(
              find.ancestor(
                of: find.text('Continuar'),
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              ),
            )
            .onPressed !=
        null;

    testWidgets('pide mínimo 10: antes no deja continuar', (tester) async {
      await _pump(tester, Routes.words, config: quick);
      await add(tester, 9);
      expect(find.text('9 de 20'), findsOneWidget);
      expect(find.text('Ya pueden jugar'), findsNothing);
      expect(canContinue(tester), isFalse);

      await add(tester, 1, from: 9);
      expect(find.text('10 de 20'), findsOneWidget);
      expect(find.text('Ya pueden jugar'), findsOneWidget);
      expect(canContinue(tester), isTrue);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Turno'), findsOneWidget);
    });

    testWidgets('no deja pasar de 20', (tester) async {
      final container = await _pump(tester, Routes.words, config: quick);
      await add(tester, 20);
      expect(find.text('20 de 20'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(
        container.read(gameControllerProvider).currentDeck,
        hasLength(GameConfig.quickMaxWords),
      );
    });
  });

  group('resultado de la partida rápida', () {
    void played(ProviderContainer container) {
      final game = container.read(gameControllerProvider.notifier);
      game.startWithWords([Word('Pizza'), Word('Jirafa'), Word('Titanic')]);
      game.finishTurn(
        Turn(
          round: 1,
          groupIndex: 0,
          entries: [
            TurnEntry(Word('Pizza'), WordOutcome.hit),
            TurnEntry(Word('Jirafa'), WordOutcome.hit),
            TurnEntry(Word('Titanic'), WordOutcome.pass),
          ],
        ),
      );
    }

    final quick = QuickGame.config(
      const GameConfig(
        category: GameCategory.animals,
        wordSource: WordSource.random,
      ),
    );

    testWidgets('muestra los aciertos, sin ganador, y sus tres botones', (
      tester,
    ) async {
      await _pump(tester, Routes.turnResult, config: quick, setUp: played);
      expect(find.text('¡Tiempo!'), findsOneWidget);
      expect(find.text('Animales · Partida rápida'), findsOneWidget);
      expect(find.text('Aciertos'), findsOneWidget);
      expect(find.text('2 Correctos'), findsOneWidget);
      // Los puntos de cada palabra, según la puntuación (por frase).
      expect(find.text('+1'), findsNWidgets(2));
      expect(find.text('0'), findsOneWidget);
      expect(find.text('1 Pase'), findsOneWidget);
      expect(find.text('Otra rápida'), findsOneWidget);
      expect(find.text('Personalizada'), findsOneWidget);
      expect(find.text('Salir de la categoría'), findsOneWidget);
      expect(find.text('Finalizar juego'), findsNothing);
      expect(find.textContaining('Ruleta'), findsNothing);
    });

    testWidgets('"Otra rápida" pide palabras nuevas', (tester) async {
      final container = await _pump(
        tester,
        Routes.turnResult,
        config: quick,
        setUp: played,
      );
      await tester.tap(find.text('Otra rápida'));
      await tester.pumpAndSettle();
      expect(find.text('Descargando'), findsOneWidget);
      final game = container.read(gameControllerProvider);
      expect(game.config.quick, isTrue);
      expect(game.config.category, GameCategory.animals);
      expect(game.turns, isEmpty);
    });

    testWidgets('"Personalizada" va a la configuración con la misma '
        'categoría', (tester) async {
      final container = await _pump(
        tester,
        Routes.turnResult,
        config: quick,
        setUp: played,
      );
      await tester.tap(find.text('Personalizada'));
      await tester.pumpAndSettle();
      expect(find.text('Config'), findsOneWidget);
      final config = container.read(gameControllerProvider).config;
      expect(config.quick, isFalse);
      expect(config.category, GameCategory.animals);
    });

    testWidgets('"Salir de la categoría" vuelve a Categorías', (tester) async {
      await _pump(tester, Routes.turnResult, config: quick, setUp: played);
      await tester.tap(find.text('Salir de la categoría'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Libre'), findsWidgets);
    });
  });

  testWidgets('en la partida personalizada, "Continuar" dice a quién le toca '
      'y en el último turno, "Ver resultados"', (tester) async {
    final container = await _pump(
      tester,
      Routes.turnResult,
      config: const GameConfig(
        groups: [Group('Los Primos'), Group('Los Tigres')],
        rounds: 1,
      ),
      setUp: (container) {
        final game = container.read(gameControllerProvider.notifier);
        game.startWithDecks([
          [Word('Pizza')],
          [Word('Titanic')],
        ]);
        game.finishTurn(
          Turn(
            round: 1,
            groupIndex: 0,
            entries: [TurnEntry(Word('Pizza'), WordOutcome.hit)],
          ),
        );
      },
    );
    expect(find.text('Los Primos · Ronda 1 de 1'), findsOneWidget);
    expect(find.text('Turno de Los Tigres'), findsOneWidget);
    await tester.tap(find.text('Turno de Los Tigres'));
    await tester.pumpAndSettle();
    expect(find.text('Turno'), findsOneWidget);

    final game = container.read(gameControllerProvider.notifier);
    game.finishTurn(
      Turn(
        round: 1,
        groupIndex: 1,
        entries: [TurnEntry(Word('Titanic'), WordOutcome.pass)],
      ),
    );
    expect(game.afterAdvance.finished, isTrue);
  });

  testWidgets('con puntuación por palabra, cada palabra muestra sus puntos', (
    tester,
  ) async {
    await _pump(
      tester,
      Routes.turnResult,
      config: const GameConfig(
        groups: [Group('Los Primos'), Group('Los Tigres')],
        scoringMode: ScoringMode.perWord,
      ),
      setUp: (container) {
        final game = container.read(gameControllerProvider.notifier);
        game.startWithDecks([
          [Word('Pizza con piña'), Word('Gato')],
          [Word('Titanic')],
        ]);
        game.finishTurn(
          Turn(
            round: 1,
            groupIndex: 0,
            entries: [
              TurnEntry(Word('Pizza con piña'), WordOutcome.hit),
              TurnEntry(Word('Gato'), WordOutcome.pass),
            ],
          ),
        );
      },
    );
    expect(find.text('+3'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
  });
}
