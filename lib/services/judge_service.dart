import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/models.dart';

/// No se pudo crear la sala del celular juez. [offline] si fue por falta de
/// internet.
class JudgeException implements Exception {
  const JudgeException(this.message, {this.offline = false});

  final String message;
  final bool offline;

  static const noInternet = JudgeException(
    'El celular juez necesita internet en los dos celulares.',
    offline: true,
  );

  @override
  String toString() => 'JudgeException($message)';
}

/// Lo que el celular de la frente le cuenta al juez: el estado del turno.
/// Solo datos del juego (palabra, tiempo, equipo y puntos), nada personal.
class JudgeState {
  const JudgeState({
    required this.phase,
    this.word,
    this.category,
    this.seconds = 0,
    this.team,
    this.points = 0,
    this.hits,
    this.passes,
  });

  /// `esperando`, `jugando`, `fin_turno` o `fin_partida`.
  final String phase;
  final String? word;
  final String? category;
  final int seconds;
  final String? team;
  final int points;

  /// Resumen del turno, al terminar.
  final int? hits;
  final int? passes;

  static const waiting = 'esperando';
  static const playing = 'jugando';
  static const turnOver = 'fin_turno';
  static const gameOver = 'fin_partida';

  static String? _cut(String? text, int max) =>
      text == null || text.length <= max ? text : text.substring(0, max);

  Map<String, Object?> toJson() => {
    'tipo': 'estado',
    'palabra': _cut(word, 120),
    'categoria': _cut(category, 60),
    'segundos': seconds.clamp(0, 3600),
    'equipo': _cut(team, 60),
    'puntos': points.clamp(-9999, 99999),
    'estado': phase,
    'aciertos': ?hits,
    'pasadas': ?passes,
  };
}

/// Una sala del celular juez, del lado del celular de la frente (el
/// anfitrión). Mantiene la conexión con la sala (y se reconecta sola si se
/// corta), le manda el estado del turno y avisa cuando el juez marca.
class JudgeRoom {
  JudgeRoom({
    required this.code,
    required this.token,
    required this.baseUrl,
    WebSocketChannel Function(Uri uri)? connect,
  }) : _connect = connect ?? WebSocketChannel.connect;

  final String code;
  final String token;
  final String baseUrl;
  final WebSocketChannel Function(Uri uri) _connect;

  /// La página del juez, la que abre el QR.
  String get judgeUrl => '$baseUrl/$code';

  /// Cuántos jueces están conectados.
  final judges = ValueNotifier<int>(0);

  /// Verdadero mientras el celular está conectado con la sala.
  final connected = ValueNotifier<bool>(false);

  /// Verdadero si la sala ya no existe (se borró o la abrió otro celular):
  /// hay que crear otra.
  final gone = ValueNotifier<bool>(false);

  final _actions = StreamController<WordOutcome>.broadcast();

  /// Lo que marca el juez: acierto o pasar.
  Stream<WordOutcome> get actions => _actions.stream;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  var _wait = const Duration(seconds: 1);
  var _closed = false;
  String? _lastState;
  final _seen = <String>{};

  Uri get socketUri {
    final base = Uri.parse(baseUrl);
    return base.replace(
      scheme: base.scheme == 'http' ? 'ws' : 'wss',
      path: '${base.path}/api/salas/$code/ws',
      queryParameters: {'rol': 'anfitrion', 'token': token},
    );
  }

  /// Se conecta con la sala. Si se corta, vuelve a intentar sola.
  void open() {
    if (_closed || _channel != null) return;
    final channel = _connect(socketUri);
    _channel = channel;
    channel.ready.then((_) {
      if (_channel != channel) return;
      connected.value = true;
      _wait = const Duration(seconds: 1);
      // Al volver, el juez ve otra vez el último estado.
      final last = _lastState;
      if (last != null) channel.sink.add(last);
    }, onError: (_) {});
    _sub = channel.stream.listen(
      _onMessage,
      onDone: () => _lost(channel.closeCode),
      onError: (_) => _lost(null),
      cancelOnError: true,
    );
  }

  void _onMessage(dynamic data) {
    if (data is! String) return;
    final Object? msg;
    try {
      msg = jsonDecode(data);
    } on FormatException {
      return;
    }
    if (msg is! Map<String, dynamic>) return;
    switch (msg['tipo']) {
      case 'jueces':
        final count = msg['cantidad'];
        if (count is int) judges.value = count;
      case 'accion':
        final id = '${msg['id']}';
        // Una acción reenviada no cuenta dos veces.
        if (!_seen.add(id)) return;
        if (_seen.length > 200) _seen.remove(_seen.first);
        final outcome = switch (msg['accion']) {
          'acierto' => WordOutcome.hit,
          'pasar' => WordOutcome.pass,
          _ => null,
        };
        if (outcome != null) _actions.add(outcome);
      case 'error':
        final code = msg['codigo'];
        if (code == 'sala_no_existe' ||
            code == 'sala_cerrada' ||
            code == 'token_invalido' ||
            code == 'otro_anfitrion') {
          gone.value = true;
        }
    }
  }

  /// Se cortó la conexión: los jueces ya no cuentan y se reintenta, salvo
  /// que la sala ya no exista.
  void _lost(int? closeCode) {
    _sub?.cancel();
    _sub = null;
    _channel = null;
    connected.value = false;
    judges.value = 0;
    if (closeCode != null && closeCode >= 4000 && closeCode != 4409) {
      gone.value = true;
    }
    if (_closed || gone.value) return;
    _retry?.cancel();
    _retry = Timer(_wait, open);
    _wait = _wait * 2 > const Duration(seconds: 8)
        ? const Duration(seconds: 8)
        : _wait * 2;
  }

  /// Le manda a la sala el estado del turno, solo si cambió.
  void send(JudgeState state) {
    final text = jsonEncode(state.toJson());
    if (text == _lastState) return;
    _lastState = text;
    if (connected.value) _channel?.sink.add(text);
  }

  /// Cierra la sala de este lado. Se borra sola en el servidor.
  Future<void> close() async {
    _closed = true;
    _retry?.cancel();
    // Primero se le avisa a la sala; después se deja de escuchar.
    final channel = _channel;
    _channel = null;
    final closing = channel?.sink.close(1000);
    await _sub?.cancel();
    _sub = null;
    connected.value = false;
    judges.value = 0;
    await closing;
    await _actions.close();
  }
}

/// Crea salas del celular juez en el Worker (`server/juez`).
class JudgeService {
  JudgeService({http.Client? client, String? baseUrl, this.connect})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? defaultBaseUrl;

  /// Se puede cambiar al compilar con `--dart-define=JUEZ_URL=https://...`.
  static const defaultBaseUrl = String.fromEnvironment(
    'JUEZ_URL',
    defaultValue: 'https://valkiriacode.com/juez',
  );

  static const _timeout = Duration(seconds: 12);

  final http.Client _client;
  final String baseUrl;
  final WebSocketChannel Function(Uri uri)? connect;

  /// Crea una sala nueva y se conecta con ella.
  Future<JudgeRoom> create() async {
    final http.Response response;
    try {
      response = await _client
          .post(Uri.parse('$baseUrl/api/salas'))
          .timeout(_timeout);
    } on Exception catch (e) {
      debugPrint('[Juez] Sin respuesta: $e');
      throw JudgeException.noInternet;
    }
    Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      body = null;
    }
    if (response.statusCode != 201 && response.statusCode != 200) {
      debugPrint('[Juez] ${response.statusCode} $body');
      throw JudgeException(
        response.statusCode == 429
            ? 'Se crearon muchas salas seguidas. Espera un minuto.'
            : 'No se pudo crear la sala. Inténtalo otra vez.',
      );
    }
    final data = body is Map<String, dynamic> ? body : const {};
    final code = data['codigo'];
    final token = data['tokenAnfitrion'];
    if (code is! String || token is! String) {
      throw const JudgeException(
        'No se pudo crear la sala. Inténtalo otra vez.',
      );
    }
    return JudgeRoom(
      code: code,
      token: token,
      baseUrl: baseUrl,
      connect: connect,
    )..open();
  }
}
