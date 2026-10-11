import 'dart:math';

import 'package:camera/camera.dart';

import 'category.dart';
import 'group.dart';

/// Cómo se suman los puntos de una palabra acertada.
enum ScoringMode {
  /// Un punto por cada palabra de la frase.
  perWord('Por palabra', 'Un punto por cada palabra de la frase'),

  /// Un punto por frase, sin importar su largo.
  perPhrase('Por frase', 'Un punto por frase, sin importar su largo');

  const ScoringMode(this.label, this.description);

  final String label;
  final String description;

  int pointsFor(int wordCount) => switch (this) {
    ScoringMode.perWord => wordCount,
    ScoringMode.perPhrase => 1,
  };
}

/// Cómo se marcan los aciertos durante un turno.
enum HitMode {
  /// El jugador inclina el celular: abajo es acierto, arriba es pasar.
  tilt(
    'Movimiento',
    'Inclinen el celular hacia abajo si aciertan y hacia arriba para pasar.',
    available: true,
  ),

  /// La palabra se ve en el televisor y un juez del grupo rival marca con
  /// los botones del celular. Se activa solo cuando el celular duplica la
  /// pantalla en un TV, en cualquier categoría.
  tv('Modo TV', null, available: true),

  /// Un jugador rival marca desde un segundo celular.
  judge('Celular juez', null, available: false);

  const HitMode(this.label, this.description, {required this.available});

  final String label;
  final String? description;

  /// Falso mientras el modo no esté implementado.
  final bool available;

  /// Modos que se muestran en la sección de aciertos. El Modo TV tiene su
  /// propia sección.
  static List<HitMode> get selectable => [
    for (final mode in values)
      if (mode != tv) mode,
  ];
}

/// De dónde salen las palabras de la partida.
enum WordSource {
  /// Entregadas por Directus al empezar la partida. Sin internet se usan
  /// las últimas que se descargaron.
  random('Automáticas', available: true),

  /// Cada grupo escribe las palabras de sus rivales. Funciona sin internet.
  groups('Escritas por los grupos', available: true);

  const WordSource(this.label, {required this.available});

  final String label;

  /// Falso mientras la fuente no esté implementada.
  final bool available;
}

/// Dificultad de las palabras automáticas. Las palabras escritas por los
/// grupos no tienen dificultad.
enum Difficulty {
  /// De todas las dificultades. Es la que viene elegida.
  mixed(
    'Mezcladas',
    null,
    'Fáciles, normales y difíciles: el doble de variedad.',
  ),
  easy(
    'Fácil',
    'FACIL',
    'Palabras comunes y fáciles de actuar. Ideal con niños.',
  ),
  normal('Normal', 'NORMAL', 'Menos comunes o con más detalle.'),
  hard('Difícil', 'DIFICIL', 'Poco conocidas, abstractas o emociones.');

  const Difficulty(this.label, this.code, this.description);

  /// Palabras de cada dificultad en cada categoría de Directus. Si la base
  /// crece, se sube aquí y el máximo de palabras por turno sube solo.
  static const wordsPerDifficulty = 100;

  final String label;

  /// Valor del campo `dificultad` en Directus, o null para traer de todas.
  final String? code;
  final String description;

  /// Palabras de la categoría con esta dificultad.
  int get stock => this == mixed
      ? wordsPerDifficulty * (values.length - 1)
      : wordsPerDifficulty;
}

/// Cómo se define la duración de la partida con palabras automáticas. En
/// los dos casos se juegan las rondas elegidas; cambia si el turno tiene un
/// número fijo de palabras.
enum GameLength {
  /// Se eligen las rondas y cada turno dura hasta que se acabe el tiempo:
  /// las palabras no tienen límite.
  rounds(
    'Por número de rondas',
    'Cada turno dura hasta que se acabe el tiempo, sin límite de palabras.',
  ),

  /// Se eligen también cuántas palabras tiene cada grupo en su turno.
  wordsPerRound(
    'Palabras por ronda',
    'Ustedes eligen cuántas palabras tiene cada grupo en cada ronda.',
  );

  const GameLength(this.label, this.description);

  final String label;
  final String description;
}

/// Resolución de los videos de cada turno.
enum VideoResolution {
  /// No se abre la cámara ni se graba.
  off('Jugar sin grabar', null, premium: false),
  normal('Normal (480p)', ResolutionPreset.medium, premium: false),
  hd('HD (720p)', ResolutionPreset.high, premium: false),
  fullHd('Full HD (1080p)', ResolutionPreset.veryHigh, premium: true),
  max('Máxima', ResolutionPreset.max, premium: true);

  const VideoResolution(this.label, this.preset, {required this.premium});

  final String label;

  /// Null si no se graba.
  final ResolutionPreset? preset;

  bool get records => preset != null;

  /// Las resoluciones premium se desbloquean con una compra.
  final bool premium;
}

/// Opciones elegidas antes de empezar la partida.
class GameConfig {
  const GameConfig({
    this.turnDuration = const Duration(seconds: 60),
    this.rounds = 3,
    this.groups = const [Group(''), Group('')],
    this.category = GameCategory.free,
    this.wordSource = WordSource.groups,
    this.difficulty,
    this.wordsPerGroup = 10,
    this.wordsPerTurn = 12,
    this.gameLength = GameLength.rounds,
    this.scoringMode = ScoringMode.perWord,
    this.hitMode = HitMode.tilt,
    this.resolution = VideoResolution.hd,
  });

  static const minGroups = 2;
  static const maxGroups = 4;
  static const minRounds = 1;
  static const maxRounds = 10;
  static const minTurnSeconds = 30;
  static const maxTurnSeconds = 90;
  static const minWordsPerGroup = 5;
  static const maxWordsPerGroup = 50;
  static const minWordsPerTurn = 3;

  /// Tope de palabras por grupo en cada ronda, aunque el tiempo o la base
  /// permitan más.
  static const wordsPerTurnCap = 15;

  final Duration turnDuration;
  final int rounds;
  final List<Group> groups;

  /// Categoría de las palabras automáticas. Las de una categoría distinta
  /// de Libre siempre son automáticas.
  final GameCategory category;
  final WordSource wordSource;

  /// Dificultad de las palabras automáticas, o null si no aplica (palabras
  /// escritas por los grupos).
  final Difficulty? difficulty;

  /// Palabras que juega cada grupo: las que escriben sus rivales, o las
  /// que se descargan en el modo automático.
  final int wordsPerGroup;

  /// Palabras automáticas de cada turno: cada grupo tiene estas palabras
  /// cuando le toca, distintas a las de todos los demás turnos.
  final int wordsPerTurn;

  /// Con palabras automáticas: por número de rondas (el turno dura hasta
  /// que se acabe el tiempo) o con palabras por ronda.
  final GameLength gameLength;
  final ScoringMode scoringMode;
  final HitMode hitMode;
  final VideoResolution resolution;

  int get groupCount => groups.length;

  /// Verdadero si se juega con el televisor: el celular estaba duplicando la
  /// pantalla al configurar la partida.
  bool get tvMode => hitMode == HitMode.tv;

  /// Si los turnos se graban. En el Modo TV el celular lo tiene el juez,
  /// así que no hay video.
  bool get records => !tvMode && resolution.records;

  /// Palabras de toda la partida, sumando las de todos los grupos.
  int get totalWords => wordsPerGroup * groupCount;

  /// Si cada turno tiene su propio mazo de [wordsPerTurn] palabras: con
  /// palabras automáticas y palabras por ronda.
  bool get perTurnDecks =>
      wordSource == WordSource.random && gameLength == GameLength.wordsPerRound;

  /// Si el turno dura hasta que se acabe el tiempo, sin límite de palabras:
  /// palabras automáticas por número de rondas. Las palabras nunca se
  /// acaban antes del tiempo: si faltan, vuelven las ya jugadas.
  bool get untilTimeRunsOut =>
      wordSource == WordSource.random && gameLength == GameLength.rounds;

  /// Turnos de toda la partida.
  int get turns => groupCount * rounds;

  /// Máximo de palabras por turno según el tiempo: una cada 3 segundos, lo
  /// que alcanza un grupo rápido.
  int get maxWordsPerTurnByTime =>
      max(minWordsPerTurn, turnDuration.inSeconds ~/ 3);

  /// Máximo de palabras por turno para no repetir: las de la base
  /// repartidas entre todos los turnos.
  int get maxWordsPerTurnByStock =>
      (difficulty ?? Difficulty.mixed).stock ~/ turns;

  /// Máximo del selector de palabras por turno.
  int get maxWordsPerTurn => max(
    minWordsPerTurn,
    [
      wordsPerTurnCap,
      maxWordsPerTurnByTime,
      maxWordsPerTurnByStock,
    ].reduce(min),
  );

  /// Verdadero si el máximo lo pone la base de palabras, y no el tiempo
  /// ni el tope.
  bool get limitedByStock =>
      maxWordsPerTurnByStock < min(maxWordsPerTurnByTime, wordsPerTurnCap);

  /// Valor sugerido: una palabra cada 5 segundos, el ritmo de un grupo
  /// normal.
  int get suggestedWordsPerTurn =>
      (turnDuration.inSeconds ~/ 5).clamp(minWordsPerTurn, maxWordsPerTurn);

  /// Palabras automáticas que se piden al empezar la partida: con palabras
  /// por ronda, las de todos los turnos; por número de rondas, las que
  /// alcanzaría un grupo rápido en todos los turnos.
  int get autoWordsNeeded =>
      (perTurnDecks ? wordsPerTurn : maxWordsPerTurnByTime) * turns;

  /// Última ronda de la partida.
  int get roundLimit => rounds;

  /// "Ronda 2 de 3".
  String roundLabel(int round) => 'Ronda $round de $rounds';

  GameConfig copyWith({
    Duration? turnDuration,
    int? rounds,
    List<Group>? groups,
    GameCategory? category,
    WordSource? wordSource,
    Difficulty? difficulty,
    int? wordsPerGroup,
    int? wordsPerTurn,
    GameLength? gameLength,
    ScoringMode? scoringMode,
    HitMode? hitMode,
    VideoResolution? resolution,
  }) {
    return GameConfig(
      turnDuration: turnDuration ?? this.turnDuration,
      rounds: rounds ?? this.rounds,
      groups: groups ?? this.groups,
      category: category ?? this.category,
      wordSource: wordSource ?? this.wordSource,
      difficulty: difficulty ?? this.difficulty,
      wordsPerGroup: wordsPerGroup ?? this.wordsPerGroup,
      wordsPerTurn: wordsPerTurn ?? this.wordsPerTurn,
      gameLength: gameLength ?? this.gameLength,
      scoringMode: scoringMode ?? this.scoringMode,
      hitMode: hitMode ?? this.hitMode,
      resolution: resolution ?? this.resolution,
    );
  }
}
