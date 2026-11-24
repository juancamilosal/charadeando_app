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

  /// Una de sus letras, al azar.
  String randomLetter(Random random) => letters[random.nextInt(letters.length)];

  @override
  String toString() => 'LettersTopic($id, $topic)';
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
    required this.letter,
    required this.fuse,
    required this.passes,
  });

  final LettersTopic topic;
  final String letter;

  /// Cuánto duró (el tiempo secreto).
  final Duration fuse;
  final int passes;

  /// "Cosas que hay en un baño · La P · 14 pases".
  String get summary =>
      '${topic.topic} · La $letter · '
      '${passes == 1 ? '1 pase' : '$passes pases'}';
}

/// Una partida de Letras: va sacando temáticas (sin repetir mientras
/// alcancen), sortea la letra y el tiempo secreto de cada bomba y cuenta
/// los pases.
class LettersGame {
  LettersGame(List<LettersTopic> topics, {Random? random})
    : _topics = [...topics],
      _random = random ?? Random();

  final List<LettersTopic> _topics;
  final Random _random;
  int _next = 0;

  LettersTopic? topic;
  String? letter;

  /// Tiempo secreto de la bomba actual.
  Duration fuse = Duration.zero;
  int passes = 0;

  /// Las bombas que ya explotaron.
  final bombs = <LettersBomb>[];

  /// Saca la siguiente temática, su letra y un tiempo secreto nuevo. Cuando
  /// se acaban las temáticas, vuelven a salir en otro orden.
  void nextBomb() {
    if (_topics.isEmpty) throw StateError('Sin temáticas');
    if (_next >= _topics.length) {
      _topics.shuffle(_random);
      _next = 0;
    }
    final t = _topics[_next++];
    topic = t;
    letter = t.randomLetter(_random);
    fuse = LettersRules.secretFuse(_random);
    passes = 0;
  }

  void pass() => passes++;

  /// ¡BOOM! Anota la bomba y la devuelve.
  LettersBomb explode() {
    final bomb = LettersBomb(
      topic: topic!,
      letter: letter!,
      fuse: fuse,
      passes: passes,
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
}
