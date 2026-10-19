import 'dart:async';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/turn_result_screen.dart';
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
  FakeJudgeService({
    this.offline = false,
    this.availability = JudgeAvailability.available,
  });

  final bool offline;
  final JudgeAvailability availability;
  final connections = FakeConnections();

  @override
  Future<JudgeAvailability> check() async => availability;

  @override
  Future<JudgeRoom> create() async {
    if (offline) throw JudgeException.noInternet;
    if (availability == JudgeAvailability.unavailable) {
      throw JudgeException.notAvailable;
    }
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
      FakeJudgeService? service,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
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

    testWidgets('es gratis: sin Premium no lleva candado y se enciende', (
      tester,
    ) async {
      final service = FakeJudgeService();
      final container = await pump(tester, service: service);
      expect(container.read(premiumProvider).premium, isFalse);
      expect(find.byIcon(Icons.lock), findsNothing);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumSheet), findsNothing);
      expect(find.text('K7M2PQ'), findsOneWidget);
    });

    testWidgets('la configuración tiene la sección, salvo en el Modo TV', (
      tester,
    ) async {
      await pumpConfig(
        tester,
        overrides: [judgeServiceProvider.overrideWithValue(FakeJudgeService())],
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Celular juez'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Celular juez'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pumpConfig(
        tester,
        tv: Stream.value(true),
        overrides: [judgeServiceProvider.overrideWithValue(FakeJudgeService())],
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Continuar'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Celular juez'), findsNothing);
    });

    testWidgets('si el servidor del juez no responde, la opción no se ve', (
      tester,
    ) async {
      await pumpConfig(
        tester,
        overrides: [
          judgeServiceProvider.overrideWithValue(
            FakeJudgeService(availability: JudgeAvailability.unavailable),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Continuar'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Celular juez'), findsNothing);
      // El Modo TV sigue.
      expect(find.text('Modo TV'), findsOneWidget);
    });

    testWidgets('sin internet sí se ve, y al encenderla dice por qué', (
      tester,
    ) async {
      await pumpConfig(
        tester,
        overrides: [
          judgeServiceProvider.overrideWithValue(
            FakeJudgeService(
              offline: true,
              availability: JudgeAvailability.offline,
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Celular juez'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Celular juez'), findsOneWidget);
    });

    testWidgets('si falla al crear la sala, lo dice claro y sigue apagada', (
      tester,
    ) async {
      await pump(
        tester,
        service: FakeJudgeService(availability: JudgeAvailability.unavailable),
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'El celular juez no está disponible por ahora. Pueden jugar '
          'inclinando el celular.',
        ),
        findsOneWidget,
      );
      expect(find.byType(QrImageView), findsNothing);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    test('el texto del estado del juez', () {
      expect(judgeStatus(0), 'Esperando al juez…');
      expect(judgeStatus(1), 'Juez conectado ✓');
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
      // El juez vio la misma cuenta regresiva: 3, 2, 1.
      final counts = [
        for (final s in channel.states)
          if (s['cuenta'] != null) s['cuenta'],
      ];
      expect(counts, [3, 2, 1]);
      expect(channel.states.last['estado'], 'jugando');
      expect(channel.states.last.containsKey('cuenta'), isFalse);
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
      // El juez ve que llegó: la palabra marcada con "¡Correcto!".
      expect(channel.states.last['marca'], 'acierto');
      expect(channel.states.last['palabra'], 'Pizza');
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Jirafa'), findsOneWidget);
      expect(channel.states.last['palabra'], 'Jirafa');
      expect(channel.states.last['marca'], isNull);
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
      // También cuando marca el celular (inclinando).
      expect(channel.states.last['marca'], 'pasar');
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

  group('al final del turno', () {
    Future<(ProviderContainer, FakeChannel)> show(
      WidgetTester tester, {
      bool judge = true,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.reset);
      final service = FakeJudgeService();
      final container = ProviderContainer(
        overrides: [judgeServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      if (judge) await container.read(judgeProvider.notifier).start();
      final game = container.read(gameControllerProvider.notifier);
      game.configure(
        GameConfig(
          groups: const [Group('Tigres'), Group('Águilas')],
          resolution: VideoResolution.off,
          judgePhone: judge,
          category: GameCategory.animals,
          scoringMode: ScoringMode.perWord,
        ),
      );
      game.startWithDecks([
        [Word('El Rey León'), Word('Pizza'), Word('Jirafa')],
        [Word('Shakira')],
      ]);
      game.finishTurn(
        Turn(
          round: 1,
          groupIndex: 0,
          entries: [
            TurnEntry(Word('El Rey León'), WordOutcome.hit),
            TurnEntry(Word('Pizza'), WordOutcome.pass),
          ],
        ),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: Routes.turnResult,
              routes: [
                GoRoute(
                  path: Routes.turnResult,
                  builder: (_, _) => const TurnResultScreen(),
                ),
                GoRoute(
                  path: Routes.turn,
                  builder: (_, _) => const Text('Siguiente turno'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (container, judge ? service.connections.last : FakeChannel(Uri()));
    }

    testWidgets('sin juez, tocar una palabra la corrige y cambia los puntos', (
      tester,
    ) async {
      final (container, _) = await show(tester, judge: false);
      expect(find.text('Toca una palabra si se marcó mal.'), findsOneWidget);
      expect(container.read(gameControllerProvider).scores, [3, 0]);
      await tester.tap(find.text('Pizza'));
      await tester.pumpAndSettle();
      expect(container.read(gameControllerProvider).scores, [4, 0]);
      expect(
        container
            .read(gameControllerProvider)
            .lastTurn!
            .hits
            .map((w) => w.text),
        ['El Rey León', 'Pizza'],
      );
      // Y de vuelta.
      await tester.tap(find.text('El Rey León'));
      await tester.pumpAndSettle();
      expect(container.read(gameControllerProvider).scores, [1, 0]);
    });

    testWidgets('el juez corrige desde su página y se ve en el celular; al '
        'seguir, ya no puede', (tester) async {
      final (container, channel) = await show(tester);
      channel.receive({
        'tipo': 'accion',
        'accion': 'corregir',
        'id': 'c1',
        'indice': 0,
        'acierto': false,
      });
      await tester.pump();
      await tester.pump();
      expect(container.read(gameControllerProvider).scores, [0, 0]);
      expect(
        find.text('El juez cambió "El Rey León" a ⏭️ pasada.'),
        findsOneWidget,
      );
      // El juez ve la lista corregida, todavía editable.
      final summary = channel.states.last;
      expect(summary['estado'], 'fin_turno');
      expect(summary['editable'], isTrue);
      expect(summary['palabras'], [
        {'texto': 'El Rey León', 'acierto': false, 'puntos': 3},
        {'texto': 'Pizza', 'acierto': false, 'puntos': 1},
      ]);
      expect(summary['aciertos'], 0);
      expect(summary['pasadas'], 2);

      // Una corrección del celular también le llega al juez.
      await tester.tap(find.text('Pizza'));
      await tester.pumpAndSettle();
      expect(channel.states.last['palabras'][1]['acierto'], isTrue);
      expect(channel.states.last['puntos'], 1);

      // Al seguir al siguiente turno, el resumen queda fijo.
      await tester.tap(find.text('Turno de Águilas'));
      await tester.pump();
      expect(channel.states.last['editable'], isFalse);
      expect(channel.states.last['palabras'], hasLength(2));
    });

    testWidgets('"QR Juez" muestra el QR, la página y el código', (
      tester,
    ) async {
      await show(tester);
      await tester.tap(find.text('QR Juez'));
      await tester.pumpAndSettle();
      final qr = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(QrImageView),
      );
      expect(qr, findsOneWidget);
      Finder inDialog(String text) =>
          find.descendant(of: find.byType(Dialog), matching: find.text(text));
      expect(inDialog('K7M2PQ'), findsOneWidget);
      expect(inDialog('valkiriacode.com/juez'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('sin juez no hay botón "QR Juez"', (tester) async {
      await show(tester, judge: false);
      expect(find.text('QR Juez'), findsNothing);
    });

    test('al final, el juez recibe las posiciones; sin equipos, el total y '
        'los puntos de cada turno', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final game = container.read(gameControllerProvider.notifier);
      game.configure(
        const GameConfig(groups: [Group('A'), Group('B'), Group('C')]),
      );
      game.startWithDecks([
        [Word('Pizza')],
        [Word('Sol')],
        [Word('Luna')],
      ]);
      game.finishTurn(
        Turn(
          round: 1,
          groupIndex: 1,
          entries: [TurnEntry(Word('Sol'), WordOutcome.hit)],
        ),
      );
      final fin = judgeTurnSummary(
        container.read(gameControllerProvider),
        gameOver: true,
      ).toJson();
      expect(fin['estado'], 'fin_partida');
      expect(fin['posiciones'], [
        {'nombre': 'B', 'puntos': 1},
        {'nombre': 'A', 'puntos': 0},
        {'nombre': 'C', 'puntos': 0},
      ]);
      expect(fin.containsKey('total'), isFalse);
      // A mitad de la partida, sin posiciones.
      expect(
        judgeTurnSummary(
          container.read(gameControllerProvider),
          gameOver: false,
        ).toJson().containsKey('posiciones'),
        isFalse,
      );

      // Sin equipos: cada turno muestra solo sus puntos.
      game.configure(const GameConfig(groups: [Group('')], inGroups: false));
      game.startWithDecks([
        [Word('Pizza'), Word('Sol'), Word('Luna')],
      ]);
      game.finishTurn(
        Turn(
          round: 1,
          groupIndex: 0,
          entries: [
            TurnEntry(Word('Pizza'), WordOutcome.hit),
            TurnEntry(Word('Sol'), WordOutcome.hit),
          ],
        ),
      );
      game.advance();
      game.finishTurn(
        Turn(
          round: 2,
          groupIndex: 0,
          entries: [TurnEntry(Word('Luna'), WordOutcome.hit)],
        ),
      );
      final solo = judgeTurnSummary(
        container.read(gameControllerProvider),
        gameOver: true,
      ).toJson();
      expect(solo['puntos'], 1);
      expect(solo['total'], 3);
      expect(solo.containsKey('posiciones'), isFalse);
      expect(solo['equipo'], isNull);
    });

    test('corregir el último turno recalcula los puntos', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final game = container.read(gameControllerProvider.notifier);
      game.configure(const GameConfig(groups: [Group('A'), Group('B')]));
      game.startWithDecks([
        [Word('Pizza'), Word('Jirafa')],
        [Word('Sol')],
      ]);
      game.finishTurn(
        Turn(
          round: 1,
          groupIndex: 0,
          entries: [TurnEntry(Word('Pizza'), WordOutcome.pass)],
        ),
      );
      expect(container.read(gameControllerProvider).scores, [0, 0]);
      game.correctLastTurn(0, WordOutcome.hit);
      expect(container.read(gameControllerProvider).scores, [1, 0]);
      // Fuera de rango no hace nada.
      game.correctLastTurn(5, WordOutcome.pass);
      expect(container.read(gameControllerProvider).scores, [1, 0]);
    });
  });
}
