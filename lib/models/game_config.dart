import 'dart:math';

import 'package:camera/camera.dart';

import 'category.dart';
import 'group.dart';

/// Cómo se suman los puntos de una palabra acertada.
enum ScoringMode {
  /// Un punto por frase, sin importar su largo. Es la que viene elegida.
  perPhrase('Por frase', 'Un punto por frase, sin importar su largo'),

  /// Un punto por cada palabra de la frase.
  perWord('Por palabra', 'Un punto por cada palabra de la frase');

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

  final String label;

  /// Valor del campo `dificultad` en Directus, o null para traer de todas.
  final String? code;
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
    this.scoringMode = ScoringMode.perPhrase,
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

  /// Con palabras automáticas el turno dura hasta que se acabe el tiempo,
  /// sin límite de palabras: si faltan, vuelven las ya jugadas. Las
  /// escritas por los grupos se juegan hasta acabarlas.
  bool get untilTimeRunsOut => wordSource == WordSource.random;

  /// Turnos de toda la partida.
  int get turns => groupCount * rounds;

  /// Palabras que alcanzaría un grupo rápido en un turno: una cada 3
  /// segundos.
  int get fastWordsPerTurn => max(3, turnDuration.inSeconds ~/ 3);

  /// Palabras automáticas que se piden al empezar la partida: las que
  /// alcanzaría un grupo rápido en todos los turnos.
  int get autoWordsNeeded => fastWordsPerTurn * turns;

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
      scoringMode: scoringMode ?? this.scoringMode,
      hitMode: hitMode ?? this.hitMode,
      resolution: resolution ?? this.resolution,
    );
  }
}
