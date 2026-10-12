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

/// La sección con la ruta de la ruleta a pantalla completa.
Widget _section(Widget screen) => MaterialApp.router(
  routerConfig: GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(
        path: Routes.punishmentSpin,
        builder: (_, state) => PunishmentSpinScreen(
          punishments: state.extra! as List<String>,
          random: Random(5),
        ),
      ),
    ],
  ),
);

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
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PunishmentRoulette(
              punishments: punishments,
              random: Random(42),
              onDone: () => done = true,
            ),
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
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PunishmentRoulette(
              punishments: const ['A', 'B', 'C'],
              autoStart: true,
              onDone: () {},
            ),
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

  /// Los castigos que muestra la ruleta (la de pantalla completa, si se
  /// abrió).
  List<String> wheel(WidgetTester tester) => tester
      .widget<PunishmentRoulette>(find.byType(PunishmentRoulette).last)
      .punishments;

  Future<void> spin(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pump();
    await tester.tap(find.text('Girar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('la ruleta va arriba y muestra lo que se configura; al girar '
      'pide el origen y guarda la ruleta', (tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final container = ProviderContainer(
      overrides: [punishmentStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _section(RouletteScreen(random: Random(1))),
      ),
    );
    await tester.pumpAndSettle();
    // La ruleta va arriba de la configuración.
    expect(
      tester.getTopLeft(find.byType(PunishmentRoulette)).dy,
      lessThan(tester.getTopLeft(find.text('Campos de la ruleta')).dy),
    );
    expect(wheel(tester), hasLength(6));

    // Seis campos por defecto; se bajan a tres y la ruleta cambia.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
    }
    expect(find.text('3'), findsOneWidget);
    expect(wheel(tester), hasLength(3));

    await spin(tester);
    expect(find.text('¡Parar!'), findsNothing);
    expect(store.saved, isNull);

    await tester.tap(find.text('Jugadores y app'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));
    await tester.enterText(find.byType(TextField).at(1), 'Cantar el himno');
    await tester.pump();
    // Lo escrito se ve en la ruleta; los vacíos, con "?".
    expect(wheel(tester), ['?', 'Cantar el himno', '?']);

    await spin(tester);
    // Gira a pantalla completa: solo la ruleta y "¡Parar!".
    expect(find.text('¡Parar!'), findsOneWidget);
    expect(find.text('Campos de la ruleta'), findsNothing);
    final saved = store.saved!;
    expect(saved.source, PunishmentSource.mixed);
    expect(saved.fields, 3);
    expect(saved.punishments[1], 'Cantar el himno');
    expect(systemPunishments, contains(saved.punishments[0]));
    expect(systemPunishments, contains(saved.punishments[2]));
    // Gira con los castigos completos.
    expect(wheel(tester), saved.punishments);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('"Los escriben los jugadores" exige todos los castigos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4800);
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final container = ProviderContainer(
      overrides: [punishmentStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _section(const RouletteScreen()),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
    }
    await tester.tap(find.text('Los escriben los jugadores'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Bailar');
    await tester.pump();
    expect(wheel(tester), ['Bailar', '?']);
    await spin(tester);
    expect(find.text('Escriban los 2 castigos.'), findsOneWidget);
    expect(store.saved, isNull);

    await tester.enterText(find.byType(TextField).last, 'Saltar');
    await tester.pump();
    await spin(tester);
    expect(store.saved!.punishments, ['Bailar', 'Saltar']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('"Los pone la app" muestra sus castigos en la ruleta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4800);
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [punishmentStoreProvider.overrideWithValue(MemoryStore())],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _section(RouletteScreen(random: Random(3))),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Los pone la app'));
    await tester.pumpAndSettle();
    final first = wheel(tester);
    expect(first, hasLength(6));
    expect(first.every(systemPunishments.contains), isTrue);
    await tester.tap(find.text('Otros castigos'));
    await tester.pump();
    expect(wheel(tester), isNot(first));
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
      find.text('Empataron con menos puntos: cada equipo gira su ruleta.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Girar'));
    await tester.pumpAndSettle();
    expect(find.text('Ruleta de Águilas'), findsOneWidget);
    await tester.tap(find.text('Ruleta de Águilas'));
    await tester.pumpAndSettle();

    expect(find.text('¡Ruleta de castigo para Leones!'), findsOneWidget);
    await tester.tap(find.text('Sin castigo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ruleta de castigo'), findsNothing);
  });

  testWidgets('al final, si todos empatan no hay ruleta', (tester) async {
    await finalScreen(tester, [2, 2]);
    expect(find.textContaining('Ruleta de castigo'), findsNothing);
  });

  testWidgets('se gira con el dedo, hacia un lado o hacia el otro, y cae '
      'en un castigo', (tester) async {
    mockHaptics(tester);
    tester.view.physicalSize = const Size(1080, 3600);
    addTearDown(tester.view.reset);
    for (final down in [true, false]) {
      var done = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PunishmentRoulette(
                key: ValueKey(down),
                punishments: const ['A', 'B', 'C', 'D'],
                random: Random(2),
                onDone: () => done = true,
              ),
            ),
          ),
        ),
      );
      final wheelBox = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is RoulettePainter,
        ),
      );
      // Un empujón por el lado derecho, hacia abajo o hacia arriba.
      await tester.flingFrom(
        Offset(wheelBox.right - 30, wheelBox.center.dy),
        Offset(0, down ? 200 : -200),
        2500,
      );
      await tester.pump();
      expect(find.text('Frenando…'), findsOneWidget);
      await wait(tester, const Duration(seconds: 12));
      await tester.pumpAndSettle();
      expect(find.text('¡Castigo!'), findsOneWidget);
      await tester.tap(find.text('Listo'));
      expect(done, isTrue);
    }
  });

  testWidgets('gira hacia donde se mueve el dedo: a la derecha, en el '
      'sentido del reloj, y a la izquierda, al revés', (tester) async {
    mockHaptics(tester);
    tester.view.physicalSize = const Size(1080, 3600);
    addTearDown(tester.view.reset);
    RoulettePainter painter() =>
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) => w is CustomPaint && w.painter is RoulettePainter,
                  ),
                )
                .painter!
            as RoulettePainter;
    // Arriba y abajo de la ruleta: siempre hacia donde va el dedo.
    for (final top in [true, false]) {
      for (final right in [true, false]) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: PunishmentRoulette(
                  key: ValueKey('$top$right'),
                  punishments: const ['A', 'B', 'C', 'D'],
                  random: Random(2),
                  onDone: () {},
                ),
              ),
            ),
          ),
        );
        final box = tester.getRect(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is RoulettePainter,
          ),
        );
        final before = painter().angle;
        await tester.flingFrom(
          Offset(box.center.dx, top ? box.top + 60 : box.bottom - 60),
          Offset(right ? 200 : -200, 0),
          2500,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final turned = painter().angle - before;
        expect(turned, right ? greaterThan(0) : lessThan(0));
        await wait(tester, const Duration(seconds: 12));
        await tester.pumpAndSettle();
      }
    }
  });
}
