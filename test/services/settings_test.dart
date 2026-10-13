import 'dart:io';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/screens/settings_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ajustes guardados en memoria, sin archivos.
class MemorySettingsStore extends SettingsStore {
  AppSettings? saved;

  @override
  Future<AppSettings> load() async => saved ?? const AppSettings();

  @override
  Future<void> save(AppSettings settings) async => saved = settings;
}

void main() {
  tearDown(() => ScreenOrientation.inverted = false);

  test('por defecto: música, sonidos y vibración encendidos, sin rotación '
      'invertida y con Inclinación', () {
    const s = AppSettings();
    expect(s.music, isTrue);
    expect(s.sounds, isTrue);
    expect(s.vibration, isTrue);
    expect(s.invertedRotation, isFalse);
    expect(s.controller, PlayController.tilt);
  });

  test('los ajustes se guardan en el celular y se recuperan', () async {
    final dir = await Directory.systemTemp.createTemp('ajustes');
    addTearDown(() => dir.delete(recursive: true));
    final store = SettingsStore(directory: () async => dir);
    expect((await store.load()).vibration, isTrue);
    await store.save(
      const AppSettings(
        music: false,
        sounds: false,
        vibration: false,
        invertedRotation: true,
        controller: PlayController.touch,
      ),
    );
    final loaded = await store.load();
    expect(loaded.music, isFalse);
    expect(loaded.sounds, isFalse);
    expect(loaded.vibration, isFalse);
    expect(loaded.invertedRotation, isTrue);
    expect(loaded.controller, PlayController.touch);
  });

  test('la rotación invertida gira el juego hacia la derecha', () {
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      ],
    );
    addTearDown(container.dispose);
    expect(ScreenOrientation.game, DeviceOrientation.landscapeLeft);
    container
        .read(settingsProvider.notifier)
        .update(const AppSettings(invertedRotation: true));
    expect(ScreenOrientation.game, DeviceOrientation.landscapeRight);
  });

  testWidgets('cada ajuste de la pantalla se guarda', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final store = MemorySettingsStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    for (final title in ['Música', 'Efectos de sonido', 'Vibración']) {
      await tester.tap(find.text(title));
      await tester.pump();
    }
    expect(store.saved!.music, isFalse);
    expect(store.saved!.sounds, isFalse);
    expect(store.saved!.vibration, isFalse);

    await tester.tap(find.text('Rotación invertida'));
    await tester.pump();
    expect(store.saved!.invertedRotation, isTrue);

    await tester.tap(find.text('Toque'));
    await tester.pump();
    expect(store.saved!.controller, PlayController.touch);
    expect(find.text('Fondos'), findsOneWidget);
    expect(find.text('Cómo se juega'), findsOneWidget);
  });

  group('vibración', () {
    Future<List<String>> calls(
      WidgetTester tester,
      Future<void> Function() run,
    ) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method.startsWith('HapticFeedback')) calls.add(call.method);
          return null;
        },
      );
      await run();
      return calls;
    }

    testWidgets('apagada no vibra', (tester) async {
      const haptics = Haptics(enabled: false);
      final made = await calls(tester, () async {
        await haptics.heavy();
        await haptics.light();
        await haptics.selection();
        await haptics.vibrate();
      });
      expect(made, isEmpty);
    });

    testWidgets('encendida vibra', (tester) async {
      const haptics = Haptics(enabled: true);
      final made = await calls(tester, () async {
        await haptics.heavy();
        await haptics.vibrate();
      });
      expect(made, hasLength(2));
    });

    test('el proveedor sigue el ajuste', () {
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(hapticsProvider).enabled, isTrue);
      container
          .read(settingsProvider.notifier)
          .update(const AppSettings(vibration: false));
      expect(container.read(hapticsProvider).enabled, isFalse);
    });
  });

  testWidgets('Créditos muestra de dónde salen la música y las imágenes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CreditsSheet())),
    );
    expect(find.text('Créditos'), findsOneWidget);
    expect(find.textContaining('nastelbom'), findsOneWidget);
    expect(find.textContaining('Pixabay'), findsOneWidget);
    expect(find.textContaining('Flaticon'), findsOneWidget);
  });

  test('los sonidos respetan los ajustes', () async {
    const off = SoundService(music: false, effects: false);
    expect(await off.play(SoundEffect.hit), isFalse);
  });

  test('la música suena con el ajuste encendido, se calla en el turno y '
      'en segundo plano', () {
    final player = FakeMusicPlayer();
    final music = BackgroundMusic(player)..enabled = true;
    expect(music.playing, isTrue);
    expect(player.log, ['play']);

    // El turno la silencia y al salir vuelve.
    music.hold();
    expect(music.playing, isFalse);
    music.release();
    expect(music.playing, isTrue);

    // En segundo plano se pausa.
    music.foreground = false;
    expect(music.playing, isFalse);
    music.foreground = true;
    expect(music.playing, isTrue);

    // Con "Música" apagada no suena, aunque vuelva al frente.
    music.enabled = false;
    music.foreground = false;
    music.foreground = true;
    expect(music.playing, isFalse);
    expect(player.log, ['play', 'pause', 'play', 'pause', 'play', 'pause']);
  });
}

/// Reproductor de mentira que anota lo que le piden.
class FakeMusicPlayer implements MusicPlayer {
  final log = <String>[];

  @override
  Future<void> play() async => log.add('play');

  @override
  Future<void> pause() async => log.add('pause');

  @override
  Future<void> dispose() async {}
}
