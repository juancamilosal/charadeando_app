import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/turn_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Sin carpeta de videos de verdad.
class _NoVideos extends VideoService {
  @override
  Future<void> deleteAll() async {}
}

/// Inclinación que cuenta si alguien la escucha.
class _CountingTilt extends TiltService {
  int listens = 0;

  @override
  Stream<TiltAction> actions() {
    listens++;
    return const Stream.empty();
  }
}

Future<(ProviderContainer, _CountingTilt)> _show(
  WidgetTester tester,
  PlayController controller,
) async {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (_) async => null,
  );
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);
  final tilt = _CountingTilt();
  final container = ProviderContainer(
    overrides: [
      tvConnectedProvider.overrideWith((ref) => Stream.value(false)),
      videoServiceProvider.overrideWithValue(_NoVideos()),
      tiltServiceProvider.overrideWithValue(tilt),
      settingsProvider.overrideWith(
        () => SettingsController(AppSettings(controller: controller)),
      ),
    ],
  );
  addTearDown(container.dispose);
  final game = container.read(gameControllerProvider.notifier);
  game.configure(
    const GameConfig(
      groups: [Group('Tigres'), Group('Águilas')],
      resolution: VideoResolution.off,
    ),
  );
  game.startWithDecks([
    [Word('Pizza'), Word('Jirafa'), Word('Titanic')],
    [Word('Shakira')],
  ]);
  final router = GoRouter(
    initialLocation: Routes.turn,
    routes: [
      GoRoute(path: Routes.turn, builder: (_, _) => const TurnScreen()),
      GoRoute(
        path: Routes.turnResult,
        builder: (_, _) => const Text('Resultado'),
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
  return (container, tilt);
}

Future<void> _countdown(WidgetTester tester) async {
  await tester.tap(find.text('¡Listo!'));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('con el controlador Toque, la derecha es acierto y la '
      'izquierda, pasar', (tester) async {
    final (container, tilt) = await _show(tester, PlayController.touch);
    expect(find.text('Toca a la derecha: Acierto'), findsOneWidget);
    expect(find.text('Toca a la izquierda: Pasar'), findsOneWidget);

    await _countdown(tester);
    // Una marca suave en cada borde.
    expect(find.text('Pasar'), findsOneWidget);
    expect(find.text('Acierto'), findsOneWidget);
    expect(tilt.listens, 0);

    final size = tester.getSize(find.byType(TurnScreen));
    await tester.tapAt(Offset(size.width * 0.8, size.height / 2));
    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(Offset(size.width * 0.2, size.height / 2));
    await tester.pump(const Duration(seconds: 1));
    // Se acaba el tiempo.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    expect(find.text('Resultado'), findsOneWidget);
    final turn = container.read(gameControllerProvider).lastTurn!;
    expect(turn.entries.map((e) => e.outcome), [
      WordOutcome.hit,
      WordOutcome.pass,
    ]);
  });

  testWidgets('con Inclinación se escucha el sensor y se ven sus píldoras', (
    tester,
  ) async {
    final (_, tilt) = await _show(tester, PlayController.tilt);
    expect(find.text('Acierto'), findsOneWidget);
    expect(find.text('Toca a la derecha: Acierto'), findsNothing);
    await _countdown(tester);
    expect(tilt.listens, 1);
    // Sin las marcas de los bordes.
    expect(find.text('Pasar'), findsNothing);
  });
}
