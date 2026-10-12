import 'dart:math';

import 'package:camera/camera.dart';

import 'category.dart';
import 'custom_category.dart';
import 'group.dart';
import 'word.dart';

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
  groups('Escritas por los equipos', available: true);

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
    this.inGroups = true,
    this.category = GameCategory.free,
    this.customCategory,
    this.mixCategories = const [],
    this.mixCustom = const [],
    this.wordSource = WordSource.groups,
    this.difficulty,
    this.wordsPerGroup = 10,
    this.scoringMode = ScoringMode.perPhrase,
    this.hitMode = HitMode.tilt,
    this.resolution = VideoResolution.hd,
    this.quick = false,
  });

  static const minGroups = 2;
  static const maxGroups = 4;
  static const minRounds = 1;
  static const maxRounds = 10;
  static const minTurnSeconds = 30;
  static const maxTurnSeconds = 90;
  static const minWordsPerGroup = 5;
  static const maxWordsPerGroup = 50;

  /// Palabras manuales sin grupos: una sola lista, de al menos estas.
  static const minSoloWords = 10;

  /// Partida rápida: un solo turno de este tiempo, con hasta
  /// [quickMaxWords] palabras.
  static const quickTurn = Duration(seconds: 60);
  static const quickMaxWords = 20;

  /// "Partida rápida": sin grupos, un solo turno de un minuto, sin pasar
  /// por la configuración. No cambia la última configuración guardada.
  final bool quick;
  final Duration turnDuration;
  final int rounds;
  final List<Group> groups;

  /// Se juega en grupos, cada uno con su nombre y su puntaje. Sin grupos
  /// solo salen las palabras y los jugadores se organizan como quieran: se
  /// juega como un único grupo sin nombre.
  final bool inGroups;

  /// Categoría de las palabras automáticas. Las de una categoría distinta
  /// de Libre siempre son automáticas.
  final GameCategory category;

  /// Categoría propia que se juega, o null. Sus palabras salen del
  /// celular, no de Directus, y no tienen dificultad.
  final CustomCategory? customCategory;

  /// "Combinar categorías": las categorías del juego y las propias de una
  /// partida con varias. Vacías en una partida de una sola categoría.
  final List<GameCategory> mixCategories;
  final List<CustomCategory> mixCustom;

  /// Prefijo de [Word.category] en las palabras de una categoría propia
  /// dentro de una mezcla, seguido de su id.
  static const customWordPrefix = 'mia:';

  /// Partida con palabras de varias categorías.
  bool get isMix => mixCategories.length + mixCustom.length >= 2;

  /// Si se elige la dificultad: solo con palabras automáticas que vienen de
  /// Directus. Las categorías propias no tienen dificultad.
  bool get usesDifficulty =>
      wordSource == WordSource.random &&
      (isMix ? mixCategories.isNotEmpty : customCategory == null);

  /// Nombre de la categoría que se juega, propia o del juego. En una mezcla,
  /// "Mezcla: Animales, Películas y Mi familia", o "Mezcla de 5 categorías"
  /// si son más de 3.
  String get categoryLabel {
    if (!isMix) return customCategory?.name ?? category.label;
    final names = [
      for (final c in mixCategories) c.label,
      for (final c in mixCustom) c.name,
    ];
    if (names.length > 3) return 'Mezcla de ${names.length} categorías';
    return 'Mezcla: ${names.sublist(0, names.length - 1).join(', ')} y '
        '${names.last}';
  }

  /// En una mezcla, la categoría de [word] para mostrarla arriba de la
  /// palabra ("Película", o el nombre de la categoría propia). Null en una
  /// partida de una sola categoría.
  String? wordCategoryLabel(Word word) {
    if (!isMix) return null;
    final code = word.category;
    if (code == null) return null;
    if (code.startsWith(customWordPrefix)) {
      final id = code.substring(customWordPrefix.length);
      for (final c in mixCustom) {
        if (c.id == id) return c.name;
      }
      return null;
    }
    return GameCategory.byCode(code)?.singular;
  }

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
  /// En la partida rápida, hasta [quickMaxWords].
  int get autoWordsNeeded =>
      quick ? min(quickMaxWords, fastWordsPerTurn) : fastWordsPerTurn * turns;

  /// Última ronda de la partida.
  int get roundLimit => rounds;

  /// "Ronda 2 de 3".
  String roundLabel(int round) => 'Ronda $round de $rounds';

  GameConfig copyWith({
    Duration? turnDuration,
    int? rounds,
    List<Group>? groups,
    bool? inGroups,
    GameCategory? category,
    CustomCategory? customCategory,
    bool clearCustomCategory = false,
    List<GameCategory>? mixCategories,
    List<CustomCategory>? mixCustom,
    bool clearMix = false,
    bool clearDifficulty = false,
    WordSource? wordSource,
    Difficulty? difficulty,
    int? wordsPerGroup,
    ScoringMode? scoringMode,
    HitMode? hitMode,
    VideoResolution? resolution,
    bool? quick,
  }) {
    return GameConfig(
      turnDuration: turnDuration ?? this.turnDuration,
      rounds: rounds ?? this.rounds,
      groups: groups ?? this.groups,
      inGroups: inGroups ?? this.inGroups,
      category: category ?? this.category,
      customCategory: clearCustomCategory
          ? null
          : customCategory ?? this.customCategory,
      mixCategories: clearMix ? const [] : mixCategories ?? this.mixCategories,
      mixCustom: clearMix ? const [] : mixCustom ?? this.mixCustom,
      wordSource: wordSource ?? this.wordSource,
      difficulty: clearDifficulty ? null : difficulty ?? this.difficulty,
      wordsPerGroup: wordsPerGroup ?? this.wordsPerGroup,
      scoringMode: scoringMode ?? this.scoringMode,
      hitMode: hitMode ?? this.hitMode,
      resolution: resolution ?? this.resolution,
      quick: quick ?? this.quick,
    );
  }
}
