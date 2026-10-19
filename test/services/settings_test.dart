import 'dart:io';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/screens/settings_screen.dart';
import 'package:charadeando_app/widgets/premium_sheet.dart';
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
    // Los reportes y las estadísticas anónimas vienen encendidos.
    expect(s.shareData, isTrue);
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
        shareData: false,
      ),
    );
    final loaded = await store.load();
    expect(loaded.shareData, isFalse);
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

  testWidgets('con Todo Charadeando, Ajustes muestra su tarjeta dorada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          premiumUnlockedProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    expect(find.byType(TodoCharadeandoCard), findsOneWidget);
    expect(
      find.text('¡Lo tienes todo! Gracias por apoyar Charadeando.'),
      findsOneWidget,
    );
    expect(find.text('Todas las categorías, pago único'), findsNothing);
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
    // Las compras van arriba.
    expect(find.text('Compras'), findsOneWidget);
    expect(find.text('Todo Charadeando'), findsOneWidget);
    expect(find.text('Canjear código'), findsOneWidget);
    expect(find.text('Restaurar compras'), findsOneWidget);
    Future<void> tap(String title) async {
      await tester.ensureVisible(find.text(title));
      await tester.pump();
      await tester.tap(find.text(title));
      await tester.pump();
    }

    for (final title in ['Música', 'Efectos de sonido', 'Vibración']) {
      await tap(title);
    }
    expect(store.saved!.music, isFalse);
    expect(store.saved!.sounds, isFalse);
    expect(store.saved!.vibration, isFalse);

    await tap('Rotación invertida');
    expect(store.saved!.invertedRotation, isTrue);

    await tap('Toque');
    expect(store.saved!.controller, PlayController.touch);

    // Privacidad: un solo interruptor para reportes y estadísticas.
    expect(find.text('Privacidad', skipOffstage: false), findsOneWidget);
    await tap('Enviar datos anónimos');
    expect(store.saved!.shareData, isFalse);
    expect(find.text('Fondos', skipOffstage: false), findsOneWidget);
    expect(find.text('Cómo se juega', skipOffstage: false), findsOneWidget);
  });

  testWidgets('"Califica Charadeando" abre la ficha de Play Store', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final prompt = _FakePrompt();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          reviewServiceProvider.overrideWithValue(
            ReviewService(store: ReviewStore(), prompt: prompt),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    final rate = find.text('Califica Charadeando');
    await tester.scrollUntilVisible(
      rate,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(rate);
    await tester.pump();
    expect(prompt.storeOpened, 1);
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

  testWidgets(
    'Créditos muestra de dónde salen la música, los efectos y las imágenes',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CreditsSheet())),
      );
      expect(find.text('Créditos'), findsOneWidget);
      expect(find.textContaining('nastelbom'), findsOneWidget);
      expect(find.textContaining('Pixabay'), findsNWidgets(2));
      expect(find.text('Efectos de sonido'), findsOneWidget);
      expect(find.textContaining('vadim_makes_sound'), findsOneWidget);
      expect(find.textContaining('freesound_gamestudio'), findsOneWidget);
      expect(find.textContaining('soynoviembre'), findsOneWidget);
      expect(find.textContaining('transcendedlifting'), findsOneWidget);
      expect(find.textContaining('sspsurvival'), findsOneWidget);
      expect(find.textContaining('universfield'), findsOneWidget);
      expect(find.textContaining('victorabdo'), findsOneWidget);
      expect(find.textContaining('Flaticon'), findsOneWidget);
      expect(find.textContaining('smalllikeart'), findsOneWidget);
      expect(find.textContaining('justicon'), findsOneWidget);
      expect(find.textContaining('Magnific'), findsOneWidget);
    },
  );

  test('los sonidos respetan los ajustes', () {
    final played = <SoundEffect>[];
    final player = RecordingEffectPlayer(played);
    final off = SoundService(effects: false, player: player);
    expect(off.play(SoundEffect.hit), isFalse);
    expect(played, isEmpty);
    final on = SoundService(effects: true, player: player);
    expect(on.play(SoundEffect.hit), isTrue);
    expect(played, [SoundEffect.hit]);
  });

  testWidgets('holdFor calla la música un rato y después sigue sola', (
    tester,
  ) async {
    final player = FakeMusicPlayer();
    final music = BackgroundMusic(player)..enabled = true;
    music.holdFor(const Duration(seconds: 2));
    expect(music.playing, isFalse);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(music.playing, isFalse);
    await tester.pump(const Duration(milliseconds: 200));
    expect(music.playing, isTrue);
    expect(player.log, ['play', 'pause', 'play']);
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
    // Ahí tampoco suenan los toques.
    expect(music.silenced, isTrue);
    music.release();
    expect(music.playing, isTrue);
    expect(music.silenced, isFalse);

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

/// Anota los efectos que suenan.
class RecordingEffectPlayer implements EffectPlayer {
  RecordingEffectPlayer(this.played);

  final List<SoundEffect> played;

  @override
  Future<void> play(SoundEffect effect) async => played.add(effect);
}

class _FakePrompt implements ReviewPrompt {
  int storeOpened = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> request() async {}

  @override
  Future<void> openStore() async => storeOpened++;
}
