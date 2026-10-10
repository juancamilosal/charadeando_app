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
  tilt(
    'Movimiento',
    'Inclinen el celular hacia abajo si aciertan y hacia arriba para pasar.',
    available: true,
  ),

  /// La palabra se ve en el televisor y un juez del grupo rival marca con
  /// los botones del celular. Solo con palabras manuales.
  tv(
    'Modo TV',
    'Conecten el celular al televisor: allí se ven la palabra, el tiempo y '
        'el marcador. Un juez del grupo rival marca "Pasar" y "¡Correcto!" '
        'en este celular. No se graba video.',
    available: true,
    manualOnly: true,
  ),

  /// Un jugador rival marca desde un segundo celular.
  judge('Celular juez', null, available: false);

  const HitMode(
    this.label,
    this.description, {
    required this.available,
    this.manualOnly = false,
  });

  final String label;
  final String? description;

  /// Falso mientras el modo no esté implementado.
  final bool available;

  /// Verdadero si solo se puede elegir con palabras escritas por los grupos.
  final bool manualOnly;

  /// Modos que se muestran en la configuración según de dónde salen las
  /// palabras.
  static List<HitMode> optionsFor(WordSource source) => [
    for (final mode in values)
      if (!mode.manualOnly || source == WordSource.groups) mode,
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

/// Cuándo termina la partida.
enum GameEnd {
  /// Se juegan rondas hasta que no quede ninguna palabra.
  wordsRunOut(
    'Hasta que se acaben las palabras',
    'Se juegan rondas hasta mostrar todas las palabras.',
  ),

  /// Se juega un número fijo de rondas.
  rounds(
    'Por número de rondas',
    'El juego termina al completar las rondas, o antes si se acaban las '
        'palabras.',
  );

  const GameEnd(this.label, this.description);

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
    this.wordSource = WordSource.groups,
    this.wordsPerGroup = 10,
    this.autoWordCount = 30,
    this.gameEnd = GameEnd.rounds,
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
  static const minAutoWords = 10;
  static const maxAutoWords = 100;

  final Duration turnDuration;
  final int rounds;
  final List<Group> groups;
  final WordSource wordSource;

  /// Palabras que juega cada grupo: las que escriben sus rivales, o las
  /// que se descargan en el modo automático.
  final int wordsPerGroup;

  /// Palabras de toda la partida en el modo automático, repartidas parejo
  /// entre los grupos.
  final int autoWordCount;

  /// Cuándo termina la partida. Las palabras escritas por los grupos
  /// siempre se juegan por rondas.
  final GameEnd gameEnd;
  final ScoringMode scoringMode;
  final HitMode hitMode;
  final VideoResolution resolution;

  int get groupCount => groups.length;

  /// Verdadero si se juega con el televisor. Solo existe con palabras
  /// escritas por los grupos.
  bool get tvMode => hitMode == HitMode.tv && wordSource == WordSource.groups;

  /// Si los turnos se graban. En el Modo TV el celular lo tiene el juez,
  /// así que no hay video.
  bool get records => !tvMode && resolution.records;

  /// Palabras de toda la partida, sumando las de todos los grupos.
  int get totalWords => wordsPerGroup * groupCount;

  /// Palabras automáticas de cada grupo. Si no se dividen exacto, sobran
  /// las del residuo para que todos tengan las mismas.
  int get autoWordsPerGroup => autoWordCount ~/ groupCount;

  /// Última ronda que se puede jugar, o null si se juega hasta que se
  /// acaben las palabras.
  int? get roundLimit =>
      wordSource == WordSource.random && gameEnd == GameEnd.wordsRunOut
      ? null
      : rounds;

  /// "Ronda 2 de 3", o "Ronda 2" si no hay número fijo de rondas.
  String roundLabel(int round) {
    final limit = roundLimit;
    return limit == null ? 'Ronda $round' : 'Ronda $round de $limit';
  }

  GameConfig copyWith({
    Duration? turnDuration,
    int? rounds,
    List<Group>? groups,
    WordSource? wordSource,
    int? wordsPerGroup,
    int? autoWordCount,
    GameEnd? gameEnd,
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
      autoWordCount: autoWordCount ?? this.autoWordCount,
      gameEnd: gameEnd ?? this.gameEnd,
      scoringMode: scoringMode ?? this.scoringMode,
      hitMode: hitMode ?? this.hitMode,
      resolution: resolution ?? this.resolution,
    );
  }
}
