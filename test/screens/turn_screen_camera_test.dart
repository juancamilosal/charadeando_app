import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/turn_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('si la cámara falla, cerrar el diálogo de permisos no la '
      'vuelve a abrir una y otra vez', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    var cameraCalls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/camera'),
      (_) async {
        cameraCalls++;
        throw PlatformException(code: 'CameraAccessDenied');
      },
    );
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        tvConnectedProvider.overrideWith((ref) => Stream.value(false)),
      ],
    );
    addTearDown(container.dispose);
    final game = container.read(gameControllerProvider.notifier);
    game.configure(
      const GameConfig(
        groups: [Group('Tigres'), Group('Águilas')],
        hitMode: HitMode.tilt,
        scoringMode: ScoringMode.perPhrase,
      ),
    );
    game.startWithDecks([
      [Word('Pizza')],
      [Word('Titanic')],
    ]);
    final router = GoRouter(
      initialLocation: Routes.turn,
      routes: [
        GoRoute(path: Routes.turn, builder: (_, _) => const TurnScreen()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('sin video'), findsOneWidget);
    final calls = cameraCalls;

    // El diálogo de permisos deja la app inactiva y al cerrarse vuelve.
    for (var i = 0; i < 3; i++) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }
    expect(cameraCalls, calls);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('sin video'), findsOneWidget);

    // Al volver de los ajustes (segundo plano) sí se intenta otra vez.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(cameraCalls, greaterThan(calls));
    expect(find.textContaining('sin video'), findsOneWidget);
  });
}
