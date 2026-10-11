import 'dart:math';

import '../models/models.dart';

/// Configuración que el juego elige solo con "Llenar automáticamente".
class AutoFillResult {
  const AutoFillResult({
    required this.config,
    required this.names,
    required this.gameEnd,
    required this.scoring,
    required this.hitMode,
    required this.difficulty,
  });

  /// Rondas, tiempo y cantidad de palabras; los nombres van en [names].
  final GameConfig config;
  final List<String> names;
  final GameEnd gameEnd;
  final ScoringMode scoring;
  final HitMode hitMode;

  /// Solo se usa con palabras automáticas.
  final Difficulty difficulty;
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

    final automatic = current.wordSource == WordSource.random;
    // Unas 8 a 15 palabras por grupo, en múltiplos de 5 como el selector.
    final autoWords = ((count * between(8, 15)) / 5).round() * 5;
    final config = current.copyWith(
      groups: [for (final n in names) Group(n)],
      rounds: between(2, 4),
      turnDuration: Duration(seconds: any(turnSeconds)),
      wordsPerGroup: between(5, 10),
      autoWordCount: autoWords.clamp(
        GameConfig.minAutoWords,
        GameConfig.maxAutoWords,
      ),
    );
    return AutoFillResult(
      config: config,
      names: names,
      gameEnd: automatic ? any(GameEnd.values) : current.gameEnd,
      scoring: any(ScoringMode.values),
      hitMode: any([
        for (final m in HitMode.selectable)
          if (m.available) m,
      ]),
      difficulty: any(Difficulty.values),
    );
  }
}
