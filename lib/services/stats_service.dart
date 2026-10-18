import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show max;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'directus_service.dart';

/// Estadísticas anónimas de una partida, como las recibe
/// `POST /juego/partida`. No lleva nada que identifique a una persona o al
/// celular: ni nombres de equipos, ni las palabras o el nombre de una
/// categoría propia (llega solo como MIS_CATEGORIAS).
abstract final class GameStats {
  static const myCategories = 'MIS_CATEGORIAS';

  static Map<String, Object?> build({
    required GameConfig config,
    required List<Turn> turns,
    required bool finished,
    required PlayController controller,
    required String version,
  }) {
    final (mode, categories) = _modeAndCategories(config);
    final entries = [for (final t in turns) ...t.entries];
    final hits = entries.where((e) => e.outcome == WordOutcome.hit).length;
    return {
      'modo': mode,
      'categorias': categories,
      'dificultad': config.usesDifficulty
          ? config.difficulty?.code ?? 'MEZCLADA'
          : null,
      'equipos': config.inGroups ? config.groupCount : 0,
      'rondas': config.rounds,
      'duracion_turno': config.turnDuration.inSeconds,
      'palabras_jugadas': entries.length,
      'aciertos': hits,
      'pases': entries.length - hits,
      'modo_acierto': switch (config) {
        GameConfig(hitMode: HitMode.tv) => 'TV',
        GameConfig(judgePhone: true) => 'JUEZ',
        _ => controller == PlayController.touch ? 'TOQUE' : 'INCLINACION',
      },
      'terminada': finished,
      'video': config.hitMode != HitMode.tv && config.resolution.records,
      'version_app': version,
    };
  }

  static (String, List<String>) _modeAndCategories(GameConfig config) {
    if (config.isMix) {
      final categories = [
        for (final c in config.mixCategories) c.code,
        if (config.mixCustom.isNotEmpty) myCategories,
      ];
      // Solo categorías propias: es como jugar Mis categorías.
      if (categories.length == 1) return (myCategories, categories);
      return ('COMBINADA', categories);
    }
    if (config.customCategory != null) {
      return (myCategories, const [myCategories]);
    }
    if (config.photoMime) return ('FOTOMIMICA', [config.category.code]);
    if (config.category == GameCategory.free) {
      return ('LIBRE', [config.category.code]);
    }
    return ('NORMAL', [config.category.code]);
  }
}

/// Envía las estadísticas a Directus. Si no hay internet las guarda en una
/// cola en el celular (como mucho [maxQueue]) y las manda después. Nunca
/// demora el juego ni muestra errores: todo pasa por detrás.
class StatsService {
  StatsService({
    http.Client? client,
    String? baseUrl,
    Future<Directory> Function()? directory,
    Future<String> Function()? version,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? DirectusService.defaultBaseUrl,
       _directory = directory ?? getApplicationSupportDirectory,
       _version = version ?? _appVersion;

  static const maxQueue = 50;
  static const _fileName = 'estadisticas_pendientes.json';
  static const _timeout = Duration(seconds: 15);

  final http.Client _client;
  final String _baseUrl;
  final Future<Directory> Function() _directory;
  final Future<String> Function() _version;

  /// "Enviar reportes y estadísticas anónimas".
  bool enabled = true;

  /// Una sola tarea a la vez, para que la cola no se pise.
  Future<void> _work = Future.value();

  Uri get uri => Uri.parse('$_baseUrl/juego/partida');

  static Future<String> _appVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version}+${info.buildNumber}';
  }

  /// Registra una partida y trata de enviar todo lo pendiente.
  Future<void> record({
    required GameConfig config,
    required List<Turn> turns,
    required bool finished,
    required PlayController controller,
  }) {
    if (!enabled) return Future.value();
    return _enqueue(() async {
      final stats = GameStats.build(
        config: config,
        turns: turns,
        finished: finished,
        controller: controller,
        version: await _version(),
      );
      final queue = [...await _read(), stats];
      await _write(queue.sublist(max(0, queue.length - maxQueue)));
      await _flushNow();
    });
  }

  /// Envía lo que quedó pendiente (por ejemplo, al abrir la app).
  Future<void> flush() => enabled ? _enqueue(_flushNow) : Future<void>.value();

  /// Borra lo pendiente (al apagar el ajuste).
  Future<void> clear() => _enqueue(() => _write(const []));

  Future<void> _enqueue(Future<void> Function() task) {
    final next = _work.then((_) => task()).catchError((Object e) {
      debugPrint('[Estadísticas] $e');
    });
    _work = next;
    return next;
  }

  Future<void> _flushNow() async {
    final queue = await _read();
    var sent = 0;
    for (final stats in queue) {
      if (!enabled) break;
      final result = await _send(stats);
      // Sin internet o el servidor falló: se intenta la próxima vez.
      if (result == _Send.retry) break;
      // Enviada, o el servidor la rechazó (no tiene sentido reintentar).
      sent++;
    }
    if (sent > 0) await _write(queue.sublist(sent));
  }

  Future<_Send> _send(Map<String, Object?> stats) async {
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(stats),
          )
          .timeout(_timeout);
      final code = response.statusCode;
      if (code >= 200 && code < 300) return _Send.done;
      debugPrint('[Estadísticas] $code ${response.body}');
      // 429 (muchas seguidas) y 5xx: más tarde. Otro 4xx: datos que el
      // servidor no acepta; se descartan.
      return code == 429 || code >= 500 ? _Send.retry : _Send.dropped;
    } on Object catch (e) {
      debugPrint('[Estadísticas] Sin conexión: $e');
      return _Send.retry;
    }
  }

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  Future<List<Map<String, Object?>>> _read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final json = jsonDecode(await file.readAsString());
      return [
        if (json is List)
          for (final item in json)
            if (item is Map<String, dynamic>) item,
      ];
    } on Object catch (e) {
      debugPrint('[Estadísticas] No se pudo leer la cola: $e');
      return [];
    }
  }

  Future<void> _write(List<Map<String, Object?>> queue) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(queue));
  }
}

enum _Send { done, dropped, retry }

/// Sin envíos: en las pruebas.
class NoStatsService extends StatsService {
  NoStatsService() : super(version: () async => '0.0.0');

  @override
  Future<void> record({
    required GameConfig config,
    required List<Turn> turns,
    required bool finished,
    required PlayController controller,
  }) async {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> clear() async {}
}
