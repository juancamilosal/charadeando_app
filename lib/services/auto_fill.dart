import 'dart:math';

import '../models/models.dart';

/// Configuración que el juego elige solo con "Llenar automáticamente".
class AutoFillResult {
  const AutoFillResult({
    required this.config,
    required this.names,
    required this.scoring,
    required this.hitMode,
    required this.difficulty,
    required this.length,
  });

  /// Rondas, tiempo y palabras por turno; los nombres van en [names].
  final GameConfig config;
  final List<String> names;
  final ScoringMode scoring;
  final HitMode hitMode;

  /// Solo se usa con palabras automáticas.
  final Difficulty difficulty;

  /// Duración de la partida con palabras automáticas.
  final GameLength length;
}

/// Llena la configuración por el usuario, al azar pero con valores que
/// tienen sentido para la cantidad de grupos. Cada vez sale distinta.
abstract final class AutoFill {
  static const groupNames = [
    'Los Tigres',
    'Las Águilas',
    'Los Leones',
    'Las Panteras',
    'Los Delfines',
    'Los Halcones',
    'Las Cebras',
    'Los Lobos',
    'Los Pingüinos',
    'Las Abejas',
    'Los Búhos',
    'Las Jirafas',
    'Los Koalas',
    'Las Tortugas',
    'Los Zorros',
    'Las Ardillas',
    'Los Pulpos',
    'Los Canguros',
    'Las Mariposas',
    'Los Tiburones',
  ];

  /// Segundos por turno entre los que se elige.
  static const turnSeconds = [45, 60, 75, 90];

  /// Configuración al azar para [groups] grupos, a partir de [current]
  /// (se conservan la categoría, el origen de las palabras y el video).
  /// Los nombres nunca repiten los de [previousNames], para que al tocar
  /// otra vez se note el cambio.
  static AutoFillResult pick(
    GameConfig current, {
    required int groups,
    Iterable<String> previousNames = const [],
    Random? random,
  }) {
    final rnd = random ?? Random();
    T any<T>(List<T> options) => options[rnd.nextInt(options.length)];
    int between(int min, int max) => min + rnd.nextInt(max - min + 1);

    final count = groups.clamp(GameConfig.minGroups, GameConfig.maxGroups);
    final taken = previousNames.map((n) => n.trim().toLowerCase()).toSet();
    var pool = [
      for (final n in groupNames)
        if (!taken.contains(n.toLowerCase())) n,
    ];
    if (pool.length < count) pool = [...groupNames];
    pool.shuffle(rnd);
    final names = pool.take(count).toList();

    final difficulty = any(Difficulty.values);
    final length = any(GameLength.values);
    var config = current.copyWith(
      groups: [for (final n in names) Group(n)],
      rounds: between(2, 4),
      turnDuration: Duration(seconds: any(turnSeconds)),
      wordsPerGroup: between(5, 10),
      difficulty: current.wordSource == WordSource.random ? difficulty : null,
      gameLength: length,
    );
    // Palabras por turno: el valor sugerido para el tiempo del turno, sin
    // pasar de lo que alcanza la base de palabras.
    config = config.copyWith(wordsPerTurn: config.suggestedWordsPerTurn);
    return AutoFillResult(
      config: config,
      names: names,
      scoring: any(ScoringMode.values),
      hitMode: any([
        for (final m in HitMode.selectable)
          if (m.available) m,
      ]),
      difficulty: difficulty,
      length: length,
    );
  }
}
