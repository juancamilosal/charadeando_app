import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Un WebSocket de mentira: lo que la app manda queda en [sent] y lo que
/// "llega de la sala" se mete con [receive].
class FakeChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  FakeChannel(this.uri);

  final Uri uri;
  final _incoming = StreamController<dynamic>();
  final sent = <Map<String, dynamic>>[];
  bool closedByApp = false;

  @override
  int? closeCode;
  @override
  String? closeReason;
  @override
  String? get protocol => null;
  @override
  Future<void> get ready => Future.value();
  @override
  Stream<dynamic> get stream => _incoming.stream;
  @override
  WebSocketSink get sink => _FakeSink(this);

  void receive(Map<String, Object?> msg) => _incoming.add(jsonEncode(msg));

  /// La sala corta la conexión, con [code].
  void drop([int? code]) {
    closeCode = code;
    _incoming.close();
  }

  List<Map<String, dynamic>> get states => [
    for (final m in sent)
      if (m['tipo'] == 'estado') m,
  ];
}

class _FakeSink implements WebSocketSink {
  _FakeSink(this.channel);

  final FakeChannel channel;

  @override
  void add(dynamic data) =>
      channel.sent.add(jsonDecode(data as String) as Map<String, dynamic>);
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<dynamic> stream) async {}
  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    channel.closedByApp = true;
  }

  @override
  Future<void> get done => Future.value();
}

/// Conexiones que va abriendo una sala, en orden.
class FakeConnections {
  final channels = <FakeChannel>[];

  FakeChannel get last => channels.last;

  WebSocketChannel connect(Uri uri) {
    final channel = FakeChannel(uri);
    channels.add(channel);
    return channel;
  }
}

JudgeRoom room(FakeConnections connections) => JudgeRoom(
  code: 'ABC234',
  token: 'secreto',
  baseUrl: 'https://valkiriacode.com/juez',
  connect: connections.connect,
)..open();

void main() {
  test('la página del juez y el WebSocket de la sala', () {
    final c = FakeConnections();
    final r = room(c);
    expect(r.judgeUrl, 'https://valkiriacode.com/juez/ABC234');
    expect(
      c.last.uri.toString(),
      'wss://valkiriacode.com/juez/api/salas/ABC234/ws'
      '?rol=anfitrion&token=secreto',
    );
    expect(
      JudgeRoom(
        code: 'X',
        token: 't',
        baseUrl: 'http://127.0.0.1:8787/juez',
      ).socketUri.scheme,
      'ws',
    );
  });

  test('manda el estado solo cuando cambia', () async {
    final c = FakeConnections();
    final r = room(c);
    await Future<void>.delayed(Duration.zero);
    const s = JudgeState(
      phase: JudgeState.playing,
      word: 'Jirafa',
      category: 'Animales',
      seconds: 42,
      team: 'Los Tigres',
      points: 3,
    );
    r.send(s);
    r.send(s);
    expect(c.last.states, hasLength(1));
    expect(c.last.states.single, {
      'tipo': 'estado',
      'palabra': 'Jirafa',
      'categoria': 'Animales',
      'segundos': 42,
      'equipo': 'Los Tigres',
      'puntos': 3,
      'estado': 'jugando',
    });
    r.send(
      const JudgeState(
        phase: JudgeState.turnOver,
        points: 5,
        hits: 4,
        passes: 1,
      ),
    );
    expect(c.last.states.last['aciertos'], 4);
    expect(c.last.states.last['pasadas'], 1);
    expect(c.last.states.last['palabra'], isNull);
  });

  test('lo que marca el juez llega una sola vez', () async {
    final c = FakeConnections();
    final r = room(c);
    final got = <WordOutcome>[];
    r.actions.listen(got.add);
    await Future<void>.delayed(Duration.zero);
    c.last.receive({'tipo': 'accion', 'accion': 'acierto', 'id': 'a1'});
    c.last.receive({'tipo': 'accion', 'accion': 'acierto', 'id': 'a1'});
    c.last.receive({'tipo': 'accion', 'accion': 'pasar', 'id': 'p1'});
    c.last.receive({'tipo': 'accion', 'accion': 'borrar', 'id': 'x'});
    await Future<void>.delayed(Duration.zero);
    expect(got, [WordOutcome.hit, WordOutcome.pass]);
  });

  test('las correcciones del juez llegan aparte, una sola vez', () async {
    final c = FakeConnections();
    final r = room(c);
    final got = <(int, bool)>[];
    final actions = <WordOutcome>[];
    r.corrections.listen((x) => got.add((x.index, x.hit)));
    r.actions.listen(actions.add);
    await Future<void>.delayed(Duration.zero);
    c.last.receive({
      'tipo': 'accion',
      'accion': 'corregir',
      'id': 'c1',
      'indice': 2,
      'acierto': false,
    });
    c.last.receive({
      'tipo': 'accion',
      'accion': 'corregir',
      'id': 'c1',
      'indice': 2,
      'acierto': false,
    });
    await Future<void>.delayed(Duration.zero);
    expect(got, [(2, false)]);
    expect(actions, isEmpty);
  });

  test('el resumen lleva las palabras y si se pueden corregir', () {
    const s = JudgeState(
      phase: JudgeState.turnOver,
      points: 3,
      hits: 1,
      passes: 1,
      words: [
        JudgeWord('El Rey León', hit: true, points: 3),
        JudgeWord('Pizza', hit: false),
      ],
      editable: true,
    );
    final json = s.toJson();
    expect(json['palabras'], [
      {'texto': 'El Rey León', 'acierto': true, 'puntos': 3},
      {'texto': 'Pizza', 'acierto': false, 'puntos': 1},
    ]);
    expect(json['editable'], isTrue);
    expect(s.locked().toJson()['editable'], isFalse);
    expect(s.locked().toJson()['palabras'], json['palabras']);
    // Sin palabras no se manda ni la lista ni "editable".
    expect(
      const JudgeState(phase: JudgeState.playing).toJson().keys,
      isNot(contains('palabras')),
    );
  });

  test('sabe cuántos jueces hay', () async {
    final c = FakeConnections();
    final r = room(c);
    await Future<void>.delayed(Duration.zero);
    expect(r.connected.value, isTrue);
    c.last.receive({'tipo': 'jueces', 'cantidad': 1});
    await Future<void>.delayed(Duration.zero);
    expect(r.judges.value, 1);
  });

  test('si se corta, se reconecta sola y le vuelve a mandar el estado', () {
    fakeAsync((async) {
      final c = FakeConnections();
      final r = room(c);
      async.flushMicrotasks();
      r.send(const JudgeState(phase: JudgeState.waiting, team: 'Tigres'));
      c.last.receive({'tipo': 'jueces', 'cantidad': 1});
      async.flushMicrotasks();
      c.last.drop();
      async.flushMicrotasks();
      expect(r.connected.value, isFalse);
      // Sin conexión, los jueces no cuentan (la inclinación vuelve).
      expect(r.judges.value, 0);
      expect(c.channels, hasLength(1));
      async.elapse(const Duration(seconds: 1));
      expect(c.channels, hasLength(2));
      async.flushMicrotasks();
      expect(r.connected.value, isTrue);
      expect(c.last.states.single['equipo'], 'Tigres');
    });
  });

  test('si la sala ya no existe, no insiste', () {
    fakeAsync((async) {
      final c = FakeConnections();
      final r = room(c);
      async.flushMicrotasks();
      c.last.receive({'tipo': 'error', 'codigo': 'sala_no_existe'});
      c.last.drop(4404);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 30));
      expect(r.gone.value, isTrue);
      expect(c.channels, hasLength(1));
    });
  });

  test('al cerrarla, cierra la conexión', () async {
    final c = FakeConnections();
    final r = room(c);
    await Future<void>.delayed(Duration.zero);
    await r.close();
    expect(c.last.closedByApp, isTrue);
    expect(r.connected.value, isFalse);
  });

  group('crear la sala', () {
    test('pide la sala al Worker y se conecta', () async {
      late http.Request sent;
      final c = FakeConnections();
      final service = JudgeService(
        baseUrl: 'https://valkiriacode.com/juez',
        connect: c.connect,
        client: MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({'codigo': 'K7M2PQ', 'tokenAnfitrion': 't' * 43}),
            201,
          );
        }),
      );
      final r = await service.create();
      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'https://valkiriacode.com/juez/api/salas');
      expect(r.code, 'K7M2PQ');
      expect(c.channels, hasLength(1));
      expect(JudgeService.defaultBaseUrl, 'https://valkiriacode.com/juez');
    });

    test('sin internet dice que el juez necesita internet', () async {
      final service = JudgeService(
        client: MockClient((_) async => throw const SocketException('sin red')),
      );
      await expectLater(
        service.create(),
        throwsA(
          isA<JudgeException>()
              .having((e) => e.offline, 'offline', isTrue)
              .having(
                (e) => e.message,
                'message',
                'El celular juez necesita internet en los dos celulares.',
              ),
        ),
      );
    });

    for (final (status, body) in [
      (500, '{}'),
      (404, '<html>No existe</html>'),
      (201, '{"otra": "cosa"}'),
    ]) {
      test('si el Worker no responde como debe ($status), dice que no está '
          'disponible', () async {
        final service = JudgeService(
          client: MockClient((_) async => http.Response(body, status)),
        );
        await expectLater(
          service.create(),
          throwsA(
            isA<JudgeException>()
                .having((e) => e.unavailable, 'unavailable', isTrue)
                .having(
                  (e) => e.message,
                  'message',
                  'El celular juez no está disponible por ahora. Pueden '
                      'jugar inclinando el celular.',
                ),
          ),
        );
      });
    }
  });

  group('revisar si el juez está', () {
    JudgeService answering(http.Response Function() reply) => JudgeService(
      baseUrl: 'https://valkiriacode.com/juez',
      client: MockClient((request) async {
        expect(request.url.path, '/juez/api/salud');
        return reply();
      }),
    );

    test('responde el Worker: disponible', () async {
      expect(
        await answering(
          () => http.Response(
            '{"ok": true, "servicio": "charadeando-juez"}',
            200,
          ),
        ).check(),
        JudgeAvailability.available,
      );
    });

    test(
      'la web responde otra cosa (no está publicado): no disponible',
      () async {
        for (final reply in [
          () => http.Response('<html>No existe</html>', 404),
          () => http.Response('<html>Hola</html>', 200),
          () => http.Response('{"ok": true}', 200),
          () => http.Response('{}', 502),
        ]) {
          expect(await answering(reply).check(), JudgeAvailability.unavailable);
        }
      },
    );

    test('sin internet: lo dice al encenderlo', () async {
      final service = JudgeService(
        client: MockClient((_) async => throw const SocketException('sin red')),
      );
      expect(await service.check(), JudgeAvailability.offline);
    });
  });

  test('el juez es de pago y todo pasa por canUseJudge', () {
    expect(const PremiumAccess().canUseJudge(), isFalse);
    expect(const PremiumAccess(purchased: true).canUseJudge(), isTrue);
    expect(const PremiumAccess(codeAll: true).canUseJudge(), isTrue);
    expect(
      const PremiumAccess(codeCategories: {'ANIME'}).canUseJudge(),
      isFalse,
    );
  });
}
