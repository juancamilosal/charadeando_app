import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/models.dart';

/// No se pudo crear la sala del celular juez. [offline] si fue por falta de
/// internet.
class JudgeException implements Exception {
  const JudgeException(
    this.message, {
    this.offline = false,
    this.unavailable = false,
  });

  final String message;
  final bool offline;

  /// El servidor del juez no responde como debe (por ejemplo, todavía no
  /// está publicado): por ahora no se puede usar.
  final bool unavailable;

  static const noInternet = JudgeException(
    'El celular juez necesita internet en los dos celulares.',
    offline: true,
  );

  static const notAvailable = JudgeException(
    'El celular juez no está disponible por ahora. Pueden jugar inclinando '
    'el celular.',
    unavailable: true,
  );

  @override
  String toString() => 'JudgeException($message)';
}

/// Una palabra del resumen del turno que ve el juez.
class JudgeWord {
  const JudgeWord(this.text, {required this.hit, this.points = 1});

  final String text;
  final bool hit;

  /// Puntos que da si se acertó.
  final int points;

  Map<String, Object?> toJson() => {
    'texto': JudgeState._cut(text, 120),
    'acierto': hit,
    'puntos': points.clamp(0, 99),
  };
}

/// Un equipo en la tabla de posiciones del final, con sus puntos.
class JudgeStanding {
  const JudgeStanding(this.name, this.points);

  final String name;
  final int points;

  Map<String, Object?> toJson() => {
    'nombre': JudgeState._cut(name, 60),
    'puntos': points.clamp(-9999, 99999),
  };
}

/// El juez corrigió la palabra [index] del resumen: ahora es acierto
/// ([hit]) o pasada.
class JudgeCorrection {
  const JudgeCorrection(this.index, {required this.hit});

  final int index;
  final bool hit;
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
    this.words,
    this.editable = false,
    this.mark,
    this.standings,
    this.total,
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

  /// Las palabras del turno, en orden, para el resumen.
  final List<JudgeWord>? words;

  /// Si el juez todavía puede corregirlas.
  final bool editable;

  /// Lo que se acaba de marcar en el turno ("¡Correcto!" o "Paso"), para
  /// que el juez vea que llegó; null mientras no hay marca.
  final WordOutcome? mark;

  /// Al final de la partida: los equipos de más a menos puntos (el juez ve
  /// quién ganó).
  final List<JudgeStanding>? standings;

  /// Al final de la partida sin equipos: los puntos de toda la partida.
  final int? total;

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
    if (words != null)
      'palabras': [for (final w in words!.take(100)) w.toJson()],
    if (words != null) 'editable': editable,
    if (phase == playing)
      'marca': switch (mark) {
        WordOutcome.hit => 'acierto',
        WordOutcome.pass => 'pasar',
        null => null,
      },
    if (standings != null)
      'posiciones': [for (final s in standings!.take(20)) s.toJson()],
    if (total != null) 'total': total!.clamp(-9999, 99999),
  };

  /// El mismo estado, pero ya sin poder corregir.
  JudgeState locked() => JudgeState(
    phase: phase,
    word: word,
    category: category,
    seconds: seconds,
    team: team,
    points: points,
    hits: hits,
    passes: passes,
    words: words,
    standings: standings,
    total: total,
  );
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

  final _corrections = StreamController<JudgeCorrection>.broadcast();

  /// Lo que corrige el juez en el resumen del turno.
  Stream<JudgeCorrection> get corrections => _corrections.stream;

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
        if (msg['accion'] == 'corregir') {
          final index = msg['indice'];
          final hit = msg['acierto'];
          if (index is int && hit is bool) {
            _corrections.add(JudgeCorrection(index, hit: hit));
          }
          return;
        }
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
    await _corrections.close();
  }
}

/// Si se puede usar el celular juez.
enum JudgeAvailability {
  /// El Worker responde: se muestra la opción.
  available,

  /// Sin internet: se muestra, y al encenderla dice que necesita internet.
  offline,

  /// Hay internet pero el Worker no responde como debe (por ejemplo, no
  /// está publicado): la opción no se muestra.
  unavailable,
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

  static const _timeout = Duration(seconds: 10);
  static const _checkTimeout = Duration(seconds: 6);

  /// Lo que responde `/api/salud` el Worker del juez (y no otra página del
  /// sitio).
  static const service = 'charadeando-juez';

  final http.Client _client;
  final String baseUrl;
  final WebSocketChannel Function(Uri uri)? connect;

  /// Pregunta si el Worker del juez está publicado y responde.
  Future<JudgeAvailability> check() async {
    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse('$baseUrl/api/salud'))
          .timeout(_checkTimeout);
    } on Exception catch (e) {
      debugPrint('[Juez] Sin respuesta al revisar: $e');
      return JudgeAvailability.offline;
    }
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 &&
          body is Map<String, dynamic> &&
          body['ok'] == true &&
          body['servicio'] == service) {
        return JudgeAvailability.available;
      }
    } on FormatException {
      // No es el Worker: por ejemplo, una página de la web.
    }
    debugPrint(
      '[Juez] El servidor no está disponible (${response.statusCode}).',
    );
    return JudgeAvailability.unavailable;
  }

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
    if (response.statusCode == 429) {
      throw const JudgeException(
        'Se crearon muchas salas seguidas. Espera un minuto.',
      );
    }
    final data = body is Map<String, dynamic> ? body : const {};
    final code = data['codigo'];
    final token = data['tokenAnfitrion'];
    // Cualquier otra respuesta (404 de la web, un error del servidor o algo
    // que no es la sala) es que el juez no está disponible.
    if (response.statusCode != 201 || code is! String || token is! String) {
      debugPrint('[Juez] ${response.statusCode} $body');
      throw JudgeException.notAvailable;
    }
    return JudgeRoom(
      code: code,
      token: token,
      baseUrl: baseUrl,
      connect: connect,
    )..open();
  }
}
