import 'package:camera/camera.dart';

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
  tilt('Movimiento', available: true),

  /// Un jugador rival marca desde un segundo celular.
  judge('Celular juez', available: false);

  const HitMode(this.label, {required this.available});

  final String label;

  /// Falso mientras el modo no esté implementado.
  final bool available;
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

/// Resolución de los videos de cada turno.
enum VideoResolution {
  normal('Normal (480p)', ResolutionPreset.medium, premium: false),
  hd('HD (720p)', ResolutionPreset.high, premium: false),
  fullHd('Full HD (1080p)', ResolutionPreset.veryHigh, premium: true),
  max('Máxima', ResolutionPreset.max, premium: true);

  const VideoResolution(this.label, this.preset, {required this.premium});

  final String label;
  final ResolutionPreset preset;

  /// Las resoluciones premium se desbloquean con una compra.
  final bool premium;
}

/// Opciones elegidas antes de empezar la partida.
class GameConfig {
  const GameConfig({
    this.turnDuration = const Duration(seconds: 60),
    this.rounds = 3,
    this.groups = const [Group(''), Group('')],
    this.wordSource = WordSource.groups,
    this.wordsPerGroup = 10,
    this.scoringMode = ScoringMode.perWord,
    this.hitMode = HitMode.tilt,
    this.resolution = VideoResolution.hd,
  });

  static const minGroups = 2;
  static const maxGroups = 6;
  static const minRounds = 1;
  static const maxRounds = 10;
  static const minTurnSeconds = 30;
  static const maxTurnSeconds = 180;
  static const minWordsPerGroup = 5;
  static const maxWordsPerGroup = 50;

  final Duration turnDuration;
  final int rounds;
  final List<Group> groups;
  final WordSource wordSource;

  /// Palabras que juega cada grupo: las que escriben sus rivales, o las
  /// que se descargan en el modo automático.
  final int wordsPerGroup;
  final ScoringMode scoringMode;
  final HitMode hitMode;
  final VideoResolution resolution;

  int get groupCount => groups.length;

  /// Palabras de toda la partida, sumando las de todos los grupos.
  int get totalWords => wordsPerGroup * groupCount;

  GameConfig copyWith({
    Duration? turnDuration,
    int? rounds,
    List<Group>? groups,
    WordSource? wordSource,
    int? wordsPerGroup,
    ScoringMode? scoringMode,
    HitMode? hitMode,
    VideoResolution? resolution,
  }) {
    return GameConfig(
      turnDuration: turnDuration ?? this.turnDuration,
      rounds: rounds ?? this.rounds,
      groups: groups ?? this.groups,
      wordSource: wordSource ?? this.wordSource,
      wordsPerGroup: wordsPerGroup ?? this.wordsPerGroup,
      scoringMode: scoringMode ?? this.scoringMode,
      hitMode: hitMode ?? this.hitMode,
      resolution: resolution ?? this.resolution,
    );
  }
}
