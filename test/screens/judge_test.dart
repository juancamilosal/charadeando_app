import 'dart:async';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/turn_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:charadeando_app/widgets/judge_setup.dart';
import 'package:charadeando_app/widgets/premium_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/judge_service_test.dart';
import 'config_screen_test.dart' show pumpConfig;

/// Crea salas sin internet, con WebSockets de mentira; o falla como sin
/// internet.
class FakeJudgeService extends JudgeService {
  FakeJudgeService({this.offline = false});

  final bool offline;
  final connections = FakeConnections();

  @override
  Future<JudgeRoom> create() async {
    if (offline) throw JudgeException.noInternet;
    return JudgeRoom(
      code: 'K7M2PQ',
      token: 'secreto',
      baseUrl: 'https://valkiriacode.com/juez',
      connect: connections.connect,
    )..open();
  }
}

class _NoVideos extends VideoService {
  @override
  Future<void> deleteAll() async {}
}

class _NoTilt extends TiltService {
  final controller = StreamController<TiltAction>.broadcast();

  @override
  Stream<TiltAction> actions() => controller.stream;
}

class _Silence implements EffectPlayer {
  @override
  Future<void> play(SoundEffect effect) async {}
}

void main() {
  group('en la configuración', () {
    Future<ProviderContainer> pump(
      WidgetTester tester, {
      bool unlocked = true,
      FakeJudgeService? service,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          judgeUnlockedProvider.overrideWithValue(unlocked),
          judgeServiceProvider.overrideWithValue(service ?? FakeJudgeService()),
          premiumBillingProvider.overrideWithValue(NoBilling()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: JudgeSetupView()),
            ),
          ),
        ),
      );
      return container;
    }

    testWidgets('al encenderlo crea la sala, muestra el QR y el código, y '
        'avisa cuando se conecta el juez', (tester) async {
      final service = FakeJudgeService();
      final container = await pump(tester, service: service);
      expect(find.byType(QrImageView), findsNothing);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(qr, isNotNull);
      expect(find.text('K7M2PQ'), findsOneWidget);
      expect(find.text('valkiriacode.com/juez'), findsOneWidget);
      expect(find.text('Esperando al juez…'), findsOneWidget);
      service.connections.last.receive({'tipo': 'jueces', 'cantidad': 1});
      await tester.pumpAndSettle();
      expect(find.text('Juez conectado ✓'), findsOneWidget);
      expect(container.read(judgeProvider.notifier).room?.code, 'K7M2PQ');

      // Al apagarlo se cierra la sala.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      expect(service.connections.last.closedByApp, isTrue);
      expect(container.read(judgeProvider.notifier).room, isNull);
    });

    testWidgets('sin internet lo dice y el juego sigue sin juez', (
      tester,
    ) async {
      await pump(tester, service: FakeJudgeService(offline: true));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(
        find.text('El celular juez necesita internet en los dos celulares.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('sin Premium lleva candado y abre la compra', (tester) async {
      final service = FakeJudgeService();
      await pump(tester, unlocked: false, service: service);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumSheet), findsOneWidget);
      expect(service.connections.channels, isEmpty);
    });

    testWidgets('la configuración tiene la sección, salvo en el Modo TV', (
      tester,
    ) async {
      await pumpConfig(tester);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Celular juez'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Celular juez'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pumpConfig(tester, tv: Stream.value(true));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Continuar'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Celular juez'), findsNothing);
    });

    test('el texto del estado del juez', () {
      expect(judgeStatus(0), 'Esperando al juez…');
      expect(judgeStatus(1), 'Juez conectado ✓');
      expect(judgeStatus(2), '2 jueces conectados ✓');
    });
  });

  group('en el turno', () {
    Future<(ProviderContainer, FakeChannel, _NoTilt)> show(
      WidgetTester tester, {
      PlayController controller = PlayController.tilt,
    }) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (_) async => null,
      );
      // Sin celular de verdad: la pantalla encendida no hace nada.
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
        (_) async => const StandardMessageCodec().encodeMessage(<Object?>[]),
      );
      tester.view.physicalSize = const Size(2400, 1080);
      addTearDown(tester.view.reset);
      final service = FakeJudgeService();
      final tilt = _NoTilt();
      final container = ProviderContainer(
        overrides: [
          judgeServiceProvider.overrideWithValue(service),
          effectPlayerProvider.overrideWithValue(_Silence()),
          tvConnectedProvider.overrideWith((ref) => Stream.value(false)),
          videoServiceProvider.overrideWithValue(_NoVideos()),
          tiltServiceProvider.overrideWithValue(tilt),
          settingsProvider.overrideWith(
            () => SettingsController(AppSettings(controller: controller)),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(judgeProvider.notifier).start();
      final game = container.read(gameControllerProvider.notifier);
      game.configure(
        const GameConfig(
          groups: [Group('Tigres'), Group('Águilas')],
          resolution: VideoResolution.off,
          judgePhone: true,
          category: GameCategory.animals,
        ),
      );
      game.startWithDecks([
        [Word('Pizza'), Word('Jirafa'), Word('Titanic')],
        [Word('Shakira')],
      ]);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: Routes.turn,
              routes: [
                GoRoute(
                  path: Routes.turn,
                  builder: (_, _) => const TurnScreen(),
                ),
                GoRoute(
                  path: Routes.turnResult,
                  builder: (_, _) => const Text('Resultado'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (container, service.connections.last, tilt);
    }

    Future<void> start(WidgetTester tester) async {
      await tester.tap(find.text('¡Listo!'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    testWidgets('el juez marca, la inclinación no; si se va, avisa y la '
        'inclinación vuelve', (tester) async {
      final (container, channel, tilt) = await show(tester);
      // Antes del turno el juez ve que espera a los Tigres.
      expect(channel.states.last['estado'], 'esperando');
      expect(channel.states.last['equipo'], 'Tigres');
      channel.receive({'tipo': 'jueces', 'cantidad': 1});
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Juez conectado ✓'), findsOneWidget);

      await start(tester);
      expect(channel.states.last['estado'], 'jugando');
      expect(channel.states.last['palabra'], 'Pizza');
      expect(channel.states.last['categoria'], 'Animales');
      expect(channel.states.last['puntos'], 0);

      // Con el juez conectado, inclinar no marca.
      tilt.controller.add(TiltAction.hit);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Pizza'), findsOneWidget);

      // El juez marca acierto: igual que inclinar.
      channel.receive({'tipo': 'accion', 'accion': 'acierto', 'id': 'a1'});
      await tester.pump();
      await tester.pump();
      expect(find.text('¡Correcto!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Jirafa'), findsOneWidget);
      expect(channel.states.last['palabra'], 'Jirafa');
      expect(channel.states.last['puntos'], 1);

      // Se va el juez: aviso discreto y la inclinación vuelve a marcar.
      channel.receive({'tipo': 'jueces', 'cantidad': 0});
      await tester.pump();
      await tester.pump();
      expect(
        find.text(
          'Se desconectó el celular juez: marquen inclinando el celular.',
        ),
        findsOneWidget,
      );
      tilt.controller.add(TiltAction.pass);
      await tester.pump();
      expect(find.text('Paso'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));

      // Al acabar el tiempo, el juez ve el resumen.
      for (var i = 0; i < 61; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      // Al cerrar el turno se deja de escuchar el sensor de mentira, que
      // termina fuera del tiempo de la prueba.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Resultado'), findsOneWidget);
      final last = channel.states.last;
      expect(last['estado'], 'fin_turno');
      expect(last['aciertos'], 1);
      expect(last['pasadas'], 1);
      expect(last['puntos'], 1);
      final turn = container.read(gameControllerProvider).lastTurn!;
      expect(turn.entries.map((e) => e.outcome), [
        WordOutcome.hit,
        WordOutcome.pass,
      ]);
    });

    testWidgets('con el controlador Toque, tocar no marca mientras está el '
        'juez', (tester) async {
      final (_, channel, _) = await show(
        tester,
        controller: PlayController.touch,
      );
      channel.receive({'tipo': 'jueces', 'cantidad': 1});
      await tester.pump();
      await tester.pump();
      await start(tester);
      final size = tester.getSize(find.byType(TurnScreen));
      await tester.tapAt(Offset(size.width * 0.8, size.height / 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Pizza'), findsOneWidget);
      channel.receive({'tipo': 'accion', 'accion': 'pasar', 'id': 'p1'});
      await tester.pump();
      await tester.pump();
      expect(find.text('Paso'), findsOneWidget);
      // Termina el turno para no dejar relojes andando.
      for (var i = 0; i < 61; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();
    });
  });
}
