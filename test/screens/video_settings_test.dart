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

import 'config_screen_test.dart' show MemoryConfigStore;

/// Sin carpeta de videos de verdad.
class _NoVideos extends VideoService {
  @override
  Future<void> deleteAll() async {}
}

class _MemorySettings extends SettingsStore {
  AppSettings? saved;

  @override
  Future<void> save(AppSettings settings) async => saved = settings;
}

void main() {
  testWidgets('antes del turno, "Video · HD" abre los ajustes de video: se '
      'apaga la grabación y se cambia la resolución', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    tester.view.physicalSize = const Size(2400, 1080);
    addTearDown(tester.view.reset);
    final configs = MemoryConfigStore();
    final settings = _MemorySettings();
    final container = ProviderContainer(
      overrides: [
        tvConnectedProvider.overrideWith((ref) => Stream.value(false)),
        videoServiceProvider.overrideWithValue(_NoVideos()),
        configStoreProvider.overrideWithValue(configs),
        settingsStoreProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);
    final game = container.read(gameControllerProvider.notifier);
    game.configure(const GameConfig(groups: [Group('Tigres')]));
    game.startWithDecks([
      [Word('Pizza')],
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

    await tester.tap(find.text('Video · HD'));
    await tester.pumpAndSettle();
    expect(find.text('Grabar video'), findsOneWidget);
    expect(find.text('Recomendado'), findsOneWidget);

    await tester.tap(find.text('Normal'));
    await tester.pumpAndSettle();
    expect(
      container.read(gameControllerProvider).config.resolution,
      VideoResolution.normal,
    );
    expect(configs.saved!.resolution, VideoResolution.normal);
    expect(find.text('Más liviano'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(settings.saved!.recordVideo, isFalse);
    expect(find.text('Se juega sin abrir la cámara.'), findsOneWidget);

    // Al cerrar, el botón dice que no se graba.
    await tester.tapAt(const Offset(40, 540));
    await tester.pumpAndSettle();
    expect(find.text('Sin grabar'), findsOneWidget);
  });
}
