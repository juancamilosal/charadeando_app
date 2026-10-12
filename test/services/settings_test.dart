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

  test('los sonidos respetan los ajustes', () async {
    const off = SoundService(music: false, effects: false);
    expect(await off.play(SoundEffect.hit), isFalse);
    expect(await off.startMusic(), isFalse);
  });
}
