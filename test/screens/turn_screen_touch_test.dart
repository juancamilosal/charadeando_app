import 'dart:async';

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

/// Inclinación que cuenta si alguien la escucha. [forehead] avisa cuando
/// el jugador ya tiene el celular en la frente.
class _CountingTilt extends TiltService {
  int listens = 0;
  int foreheadListens = 0;
  final forehead = StreamController<void>.broadcast();

  @override
  Stream<void> onForehead() {
    foreheadListens++;
    return forehead.stream;
  }

  @override
  Stream<TiltAction> actions() {
    listens++;
    return const Stream.empty();
  }
}

/// Efectos que sonaron en el turno.
final _played = <SoundEffect>[];

class _RecordEffects implements EffectPlayer {
  @override
  Future<void> play(SoundEffect effect) async => _played.add(effect);
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
  _played.clear();
  final container = ProviderContainer(
    overrides: [
      effectPlayerProvider.overrideWithValue(_RecordEffects()),
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
    // La palabra no toca las marcas de los bordes.
    final word = tester.getRect(find.text('Pizza'));
    final pass = tester.getRect(
      find.ancestor(of: find.text('Pasar'), matching: find.byType(Container)),
    );
    final hit = tester.getRect(
      find.ancestor(of: find.text('Acierto'), matching: find.byType(Container)),
    );
    expect(word.left, greaterThan(pass.right));
    expect(word.right, lessThan(hit.left));

    final size = tester.getSize(find.byType(TurnScreen));
    await tester.tapAt(Offset(size.width * 0.8, size.height / 2));
    await tester.pump(const Duration(seconds: 1));
    // Un pitido por número y otro al arrancar; el acierto suena a
    // "¡Correcto!" y pasar, con su propio sonido.
    const countdown = [
      SoundEffect.countdown,
      SoundEffect.countdown,
      SoundEffect.countdown,
      SoundEffect.start,
    ];
    expect(_played, [...countdown, SoundEffect.hit]);
    await tester.tapAt(Offset(size.width * 0.2, size.height / 2));
    await tester.pump(const Duration(seconds: 1));
    expect(_played, [...countdown, SoundEffect.hit, SoundEffect.pass]);
    _played.clear();
    // Se acaba el tiempo.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    expect(find.text('Resultado'), findsOneWidget);
    // El reloj sonó en cada uno de los últimos 10 segundos y la marimba
    // cerró el turno.
    expect(_played, [
      for (var i = 0; i < 10; i++) SoundEffect.clock,
      SoundEffect.timeUp,
    ]);
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
    await tester.tap(find.text('¡Listo!'));
    await tester.pump();
    // Primero se espera el celular en la frente; la cuenta todavía no.
    expect(
      find.text('Ponte el celular en la frente para comenzar'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.text('Ponte el celular en la frente para comenzar'),
      findsOneWidget,
    );
    expect(tilt.listens, 0);
    // Ya está en la frente: arranca la cuenta y después el turno.
    tilt.forehead.add(null);
    // El aviso del stream llega en la siguiente vuelta.
    await tester.pump();
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(tilt.listens, 1);
    // Sin las marcas de los bordes.
    expect(find.text('Pasar'), findsNothing);
  });

  testWidgets('si no reconoce el celular en la frente, se puede empezar '
      'igual', (tester) async {
    final (_, tilt) = await _show(tester, PlayController.tilt);
    await tester.tap(find.text('¡Listo!'));
    await tester.pump();
    expect(find.text('Empezar igual'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('Empezar igual'));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(tilt.listens, 1);
  });

  testWidgets('si no lo reconoce, a los 6 segundos la cuenta arranca sola', (
    tester,
  ) async {
    final (_, tilt) = await _show(tester, PlayController.tilt);
    await tester.tap(find.text('¡Listo!'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Empezar igual'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(tilt.listens, 1);
  });

  testWidgets('con Toque no se espera el celular en la frente', (tester) async {
    final (_, tilt) = await _show(tester, PlayController.touch);
    await tester.tap(find.text('¡Listo!'));
    await tester.pump();
    expect(
      find.text('Ponte el celular en la frente para comenzar'),
      findsNothing,
    );
    expect(tilt.foreheadListens, 0);
  });
}
