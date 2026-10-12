import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Última configuración de partida, para no volver a llenarla. Es una sola
/// para todas las categorías y se guarda en el celular: no sale de él y se
/// pierde si se desinstala la app.
class SavedConfig {
  const SavedConfig({
    required this.groupNames,
    required this.rounds,
    required this.turnDuration,
    required this.wordsPerGroup,
    required this.scoringMode,
    required this.hitMode,
    required this.resolution,
    this.difficulty,
    this.teamIds = const [],
  });

  factory SavedConfig.fromJson(Map<String, dynamic> json) {
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    final names = [
      for (final n in json['grupos'] as List? ?? const [])
        if (n is String) n,
    ];
    final hit = byName(HitMode.values, json['aciertos'], HitMode.tilt);
    return SavedConfig(
      groupNames: names,
      rounds: (json['rondas'] as num?)?.toInt() ?? 3,
      turnDuration: Duration(
        seconds: (json['segundos'] as num?)?.toInt() ?? 60,
      ),
      wordsPerGroup: (json['palabrasPorGrupo'] as num?)?.toInt() ?? 10,
      scoringMode: byName(
        ScoringMode.values,
        json['puntuacion'],
        ScoringMode.perPhrase,
      ),
      // El Modo TV depende de si hay un televisor conectado, no se guarda.
      hitMode: hit.available && hit != HitMode.tv ? hit : HitMode.tilt,
      resolution: byName(
        VideoResolution.values,
        json['video'],
        VideoResolution.hd,
      ),
      teamIds: [
        for (final id in json['equipos'] as List? ?? const [])
          if (id is String) id,
      ],
      difficulty: json['dificultad'] == null
          ? null
          : byName(Difficulty.values, json['dificultad'], Difficulty.mixed),
    );
  }

  final List<String> groupNames;
  final int rounds;
  final Duration turnDuration;
  final int wordsPerGroup;
  final ScoringMode scoringMode;
  final HitMode hitMode;
  final VideoResolution resolution;

  /// Solo con palabras automáticas.
  final Difficulty? difficulty;

  /// Equipos guardados elegidos para la partida, en orden. Los de una sola
  /// partida (como los de la configuración aleatoria) no se recuerdan.
  final List<String> teamIds;

  Map<String, dynamic> toJson() => {
    'grupos': groupNames,
    'rondas': rounds,
    'segundos': turnDuration.inSeconds,
    'palabrasPorGrupo': wordsPerGroup,
    'puntuacion': scoringMode.name,
    'aciertos': hitMode.name,
    'video': resolution.name,
    'dificultad': difficulty?.name,
    'equipos': teamIds,
  };
}

/// Lee y guarda la última configuración en un archivo del celular.
class ConfigStore {
  ConfigStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const _fileName = 'ultima_configuracion.json';

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  /// La última configuración, o null si nunca se guardó.
  Future<SavedConfig?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, dynamic> ? SavedConfig.fromJson(json) : null;
    } on Exception catch (e) {
      debugPrint('[Configuración] No se pudo leer la guardada: $e');
      return null;
    }
  }

  Future<void> save(SavedConfig config) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(config.toJson()));
    } on Exception catch (e) {
      debugPrint('[Configuración] No se pudo guardar: $e');
    }
  }
}
