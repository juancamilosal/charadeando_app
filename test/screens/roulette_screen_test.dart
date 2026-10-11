import 'dart:math';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/final_result_screen.dart';
import 'package:charadeando_app/screens/roulette_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:charadeando_app/widgets/punishment_roulette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Ruleta guardada en memoria, sin archivos.
class MemoryStore extends PunishmentStore {
  RouletteSetup? saved;

  @override
  Future<RouletteSetup?> load() async => saved;

  @override
  Future<void> save(RouletteSetup setup) async => saved = setup;
}

Future<void> wait(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

void main() {
  late List<String> haptics;

  setUp(() => haptics = []);

  void mockHaptics(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method.startsWith('Haptic')) {
          haptics.add('${call.arguments}');
        }
        return null;
      },
    );
  }

  testWidgets('gira hasta que tocan "¡Parar!" y frena en el castigo que '
      'salió al azar', (tester) async {
    mockHaptics(tester);
    tester.view.physicalSize = const Size(1080, 3600);
    addTearDown(tester.view.reset);
    const punishments = ['Cantar', 'Bailar', 'Saltar', 'Aplaudir', 'Reír'];
    final expected = punishments[Random(42).nextInt(punishments.length)];
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PunishmentRoulette(
            punishments: punishments,
            random: Random(42),
            onDone: () => done = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Girar'));
    await wait(tester, const Duration(seconds: 3));
    // Sigue girando sola, sin frenar.
    expect(find.text('¡Parar!'), findsOneWidget);
    final ticksSpinning = haptics.length;
    expect(ticksSpinning, greaterThan(20));

    await tester.tap(find.text('¡Parar!'));
    await wait(tester, const Duration(seconds: 9));
    expect(find.text('Frenando…'), findsOneWidget);
    await wait(tester, const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text('¡Castigo!'), findsOneWidget);
    expect(find.text(expected), findsOneWidget);
    expect(haptics, contains('HapticFeedbackType.heavyImpact'));
    final state = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is RoulettePainter,
      ),
    );
    final angle = (state.painter! as RoulettePainter).angle;
    expect(punishments[Roulette.fieldAt(angle, punishments.length)], expected);

    await tester.tap(find.text('Listo'));
    expect(done, isTrue);
  });

  testWidgets('si nadie toca "¡Parar!" en 30 segundos, frena sola', (
    tester,
  ) async {
    mockHaptics(tester);
    tester.view.physicalSize = const Size(1080, 3600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PunishmentRoulette(
            punishments: const ['A', 'B', 'C'],
            autoStart: true,
            onDone: () {},
          ),
        ),
      ),
    );
    await wait(tester, const Duration(seconds: 29));
    expect(find.text('¡Parar!'), findsOneWidget);
    await wait(tester, const Duration(seconds: 2));
    expect(find.text('Frenando…'), findsOneWidget);
    await wait(tester, const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('¡Castigo!'), findsOneWidget);
    expect(find.text('Girar otra vez'), findsOneWidget);
  });

  testWidgets('la sección pide elegir el origen y guarda la ruleta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3600);
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final container = ProviderContainer(
      overrides: [punishmentStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: RouletteScreen(random: Random(1))),
      ),
    );
    await tester.pumpAndSettle();

    // Seis campos por defecto; se bajan a tres.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
    }
    expect(find.text('3'), findsOneWidget);

    Future<void> next() async {
      await tester.scrollUntilVisible(
        find.text('Ir a la ruleta'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Ir a la ruleta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ir a la ruleta'));
      await tester.pumpAndSettle();
    }

    await next();
    expect(find.text('Elijan de dónde salen los castigos.'), findsOneWidget);

    await tester.tap(find.text('Mezclados'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));
    await tester.enterText(find.byType(TextField).at(1), 'Cantar el himno');
    await next();

    final saved = store.saved!;
    expect(saved.source, PunishmentSource.mixed);
    expect(saved.fields, 3);
    expect(saved.punishments[1], 'Cantar el himno');
    expect(systemPunishments, contains(saved.punishments[0]));
    expect(systemPunishments, contains(saved.punishments[2]));
    expect(find.text('Girar'), findsOneWidget);
  });

  testWidgets('"Los escribimos nosotros" exige todos los castigos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3600);
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final container = ProviderContainer(
      overrides: [punishmentStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RouletteScreen()),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
    }
    await tester.tap(find.text('Los escribimos nosotros'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Bailar');
    await tester.scrollUntilVisible(
      find.text('Ir a la ruleta'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Ir a la ruleta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ir a la ruleta'));
    await tester.pumpAndSettle();
    expect(find.text('Escriban los 2 castigos.'), findsOneWidget);
    expect(store.saved, isNull);

    await tester.enterText(find.byType(TextField).last, 'Saltar');
    await tester.scrollUntilVisible(
      find.text('Ir a la ruleta'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Ir a la ruleta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ir a la ruleta'));
    await tester.pumpAndSettle();
    expect(store.saved!.punishments, ['Bailar', 'Saltar']);
  });

  Future<ProviderContainer> finalScreen(
    WidgetTester tester,
    List<int> hitsPerGroup,
  ) async {
    tester.view.physicalSize = const Size(1080, 3600);
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [punishmentStoreProvider.overrideWithValue(MemoryStore())],
    );
    addTearDown(container.dispose);
    final game = container.read(gameControllerProvider.notifier);
    game.configure(
      GameConfig(
        groups: [
          for (final name in [
            'Tigres',
            'Águilas',
            'Leones',
          ].take(hitsPerGroup.length))
            Group(name),
        ],
        scoringMode: ScoringMode.perPhrase,
      ),
    );
    game.startWithDecks([for (final _ in hitsPerGroup) const <Word>[]]);
    for (var g = 0; g < hitsPerGroup.length; g++) {
      game.finishTurn(
        Turn(
          round: 1,
          groupIndex: g,
          entries: [
            for (var i = 0; i < hitsPerGroup[g]; i++)
              TurnEntry(Word('p$g$i'), WordOutcome.hit),
          ],
        ),
      );
    }
    final router = GoRouter(
      initialLocation: Routes.finalResult,
      routes: [
        GoRoute(
          path: Routes.finalResult,
          builder: (_, _) => const FinalResultScreen(),
        ),
        GoRoute(
          path: Routes.punishmentSpin,
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(),
              child: Text('Ruleta de ${state.extra}'),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('al final, los empatados con menos puntos giran uno después '
      'del otro', (tester) async {
    await finalScreen(tester, [3, 1, 1]);
    expect(find.text('¡Ruleta de castigo para Águilas!'), findsOneWidget);
    expect(
      find.text('Empataron con menos puntos: cada grupo gira su ruleta.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Girar'));
    await tester.tap(find.text('Girar'));
    await tester.pumpAndSettle();
    expect(find.text('Ruleta de Águilas'), findsOneWidget);
    await tester.tap(find.text('Ruleta de Águilas'));
    await tester.pumpAndSettle();

    expect(find.text('¡Ruleta de castigo para Leones!'), findsOneWidget);
    await tester.ensureVisible(find.text('Sin castigo'));
    await tester.tap(find.text('Sin castigo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ruleta de castigo'), findsNothing);
  });

  testWidgets('al final, si todos empatan no hay ruleta', (tester) async {
    await finalScreen(tester, [2, 2]);
    expect(find.textContaining('Ruleta de castigo'), findsNothing);
  });
}
