import 'dart:math';

/// Una temática del juego "Letras" ("Cosas que hay en un baño") con las
/// letras con que se puede jugar.
class LettersTopic {
  const LettersTopic({
    required this.id,
    required this.topic,
    required this.letters,
  });

  /// Lee una temática de `/juego/tematicas` (`{ id, tematica, letras }`).
  /// Null si no tiene temática.
  static LettersTopic? fromJson(Map<String, dynamic> json) {
    final topic = '${json['tematica'] ?? ''}'.trim();
    if (topic.isEmpty) return null;
    return LettersTopic(
      id: '${json['id'] ?? ''}',
      topic: topic,
      letters: LettersRules.lettersOf('${json['letras'] ?? ''}'),
    );
  }

  final String id;
  final String topic;

  /// Letras que sirven para esta temática (nunca Ñ, W, X ni Z).
  final List<String> letters;

  @override
  String toString() => 'LettersTopic($id, $topic)';
}

/// Cómo explota la bomba.
enum LettersMode {
  /// Explota en un tiempo secreto, de 20 a 60 segundos: nadie sabe cuándo.
  secret,

  /// Cada quien tiene [LettersRules.turnTime] para decir su palabra: si se
  /// le acaba el tiempo, explota en sus manos.
  turn,
}

/// Reglas del juego "Letras": la bomba.
abstract final class LettersRules {
  /// Letras del juego: todas menos Ñ, W, X y Z, que casi no tienen palabras
  /// en español. Debe coincidir con LETRAS_JUEGO de la extensión.
  static const letters = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', //
    'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'Y',
  ];

  /// La bomba explota en un tiempo secreto entre [minFuse] y [maxFuse].
  /// Largo máximo de una temática escrita por el grupo.
  static const maxTopicLength = 60;

  /// En el modo de turnos ([LettersMode.turn]): el tiempo de cada quien.
  static const turnTime = Duration(seconds: 11);

  static const minFuse = Duration(seconds: 20);
  static const maxFuse = Duration(seconds: 60);

  /// El tic-tac empieza con un tic cada [slowestTick] y, al final, uno
  /// cada [fastestTick].
  static const slowestTick = Duration(milliseconds: 1000);
  static const fastestTick = Duration(milliseconds: 140);

  /// Las letras de [value] ("abcpst"), en mayúsculas, sin repetir, en
  /// orden y solo las del juego. Si no queda ninguna, todas.
  static List<String> lettersOf(String value) {
    final set = value.toUpperCase().split('').toSet();
    final found = [
      for (final l in letters)
        if (set.contains(l)) l,
    ];
    return found.isEmpty ? letters : found;
  }

  /// El tiempo secreto de una bomba: al azar, de segundo en segundo, entre
  /// [minFuse] y [maxFuse].
  static Duration secretFuse(Random random) => Duration(
    seconds:
        minFuse.inSeconds +
        random.nextInt(maxFuse.inSeconds - minFuse.inSeconds + 1),
  );

  /// Cada cuánto suena el tic cuando ya pasó [elapsed] de una bomba de
  /// [fuse]: cada vez más rápido, como una bomba de verdad. Nadie sabe
  /// cuánto dura, pero cuando el tic-tac va a toda velocidad ya casi
  /// explota.
  static Duration tickInterval(Duration elapsed, Duration fuse) {
    final progress = fuse <= Duration.zero
        ? 1.0
        : (elapsed.inMilliseconds / fuse.inMilliseconds).clamp(0.0, 1.0);
    // Lento casi todo el tiempo y muy rápido al final.
    final eased = pow(progress, 2.2);
    final ms =
        slowestTick.inMilliseconds -
        (slowestTick.inMilliseconds - fastestTick.inMilliseconds) * eased;
    return Duration(milliseconds: ms.round());
  }
}

/// Una bomba ya jugada, para el resultado.
class LettersBomb {
  const LettersBomb({
    required this.topic,
    required this.fuse,
    required this.passes,
    required this.round,
  });

  final LettersTopic topic;

  /// Cuánto duró (el tiempo secreto).
  final Duration fuse;
  final int passes;

  /// La ronda en que explotó.
  final int round;

  /// "Cosas que hay en un baño · 14 pases · ronda 2".
  String get summary =>
      '${topic.topic} · ${passes == 1 ? '1 pase' : '$passes pases'}'
      '${round > 1 ? ' · ronda $round' : ''}';
}

/// Una partida de La Bomba (por dentro, Letras): va sacando temáticas (sin
/// repetir mientras alcancen) con su rueda de letras y el tiempo secreto de
/// cada bomba. Quien tiene el celular dice una palabra y toca la letra con
/// que empieza: esa letra queda usada. Cuando se usan todas, termina la
/// ronda: las letras vuelven a quedar libres y en la siguiente hay que
/// decir una palabra más para pasar.
class LettersGame {
  LettersGame(List<LettersTopic> topics, {Random? random})
    : _topics = [...topics],
      _random = random ?? Random();

  final List<LettersTopic> _topics;

  /// Si hay temáticas de Directus para el juego rápido.
  bool get hasTopics => _topics.isNotEmpty;
  final Random _random;
  int _next = 0;

  LettersTopic? topic;

  /// Tiempo secreto de la bomba actual.
  Duration fuse = Duration.zero;
  int passes = 0;

  /// Ronda de la bomba actual: en la ronda N hay que decir N palabras.
  int round = 1;

  /// Letras ya usadas en esta ronda.
  final used = <String>{};

  /// Las bombas que ya explotaron.
  final bombs = <LettersBomb>[];

  /// Las letras de la rueda: las 23 del juego (todas menos Ñ, W, X y Z),
  /// sea cual sea la temática. Todas se pueden tocar.
  List<String> get letters => topic == null ? const [] : LettersRules.letters;

  /// Palabras que hay que decir para pasar en esta ronda.
  int get wordsPerPass => round;

  /// Saca la siguiente temática y un tiempo secreto nuevo. Cuando se acaban
  /// las temáticas, vuelven a salir en otro orden. Con [custom] se juega
  /// con la temática que escribió el grupo (sin id: no se recuerda).
  void nextBomb({String? custom}) {
    final own = custom?.trim() ?? '';
    if (own.isNotEmpty) {
      topic = LettersTopic(id: '', topic: own, letters: LettersRules.letters);
    } else {
      if (_topics.isEmpty) throw StateError('Sin temáticas');
      if (_next >= _topics.length) {
        _topics.shuffle(_random);
        _next = 0;
      }
      topic = _topics[_next++];
    }
    fuse = LettersRules.secretFuse(_random);
    passes = 0;
    round = 1;
    used.clear();
  }

  /// Se dijo una palabra con [letter]: queda usada y cuenta el pase.
  /// Devuelve true si con ella se usaron todas (terminó la ronda). Una
  /// letra ya usada o que no es de la rueda no cuenta.
  bool choose(String letter) {
    if (!letters.contains(letter) || used.contains(letter)) return false;
    used.add(letter);
    passes++;
    return used.length >= letters.length;
  }

  /// Si la ronda ya terminó (todas las letras usadas).
  bool get roundOver => letters.isNotEmpty && used.length >= letters.length;

  /// Empieza la ronda siguiente: todas las letras libres otra vez.
  void nextRound() {
    round++;
    used.clear();
  }

  /// ¡BOOM! Anota la bomba y la devuelve.
  LettersBomb explode() {
    final bomb = LettersBomb(
      topic: topic!,
      fuse: fuse,
      passes: passes,
      round: round,
    );
    bombs.add(bomb);
    return bomb;
  }

  /// Pases de todas las bombas.
  int get totalPasses => bombs.fold(0, (sum, b) => sum + b.passes);

  /// Lo que duraron las bombas en promedio.
  Duration get averageFuse => bombs.isEmpty
      ? Duration.zero
      : Duration(
          milliseconds:
              bombs.fold(0, (sum, b) => sum + b.fuse.inMilliseconds) ~/
              bombs.length,
        );

  /// "dos", "tres"… para "Ahora debes mencionar dos palabras".
  static String number(int n) => switch (n) {
    1 => 'una',
    2 => 'dos',
    3 => 'tres',
    4 => 'cuatro',
    5 => 'cinco',
    6 => 'seis',
    7 => 'siete',
    8 => 'ocho',
    9 => 'nueve',
    10 => 'diez',
    _ => '$n',
  };
}
