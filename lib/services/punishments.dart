import 'dart:math';

/// Castigos del sistema para la ruleta. Charadeando es un juego familiar
/// (4+): castigos cortos, divertidos y sin humillar a nadie.
const systemPunishments = [
  'Imitar un animal durante 10 segundos',
  'Cantar el coro de una canción',
  'Bailar sin música durante 15 segundos',
  'Hablar como robot hasta el siguiente turno',
  'Decir un trabalenguas tres veces',
  'Caminar como pingüino por la sala',
  'Hacer 10 saltos de tijera',
  'Contar un chiste',
  'Imitar a un personaje de dibujos animados',
  'Hablar en susurros hasta el siguiente turno',
  'Hacer la mejor cara de sorpresa',
  'Decir el abecedario al revés hasta la M',
  'Caminar como cangrejo de lado a lado',
  'Aplaudir y cantar "cumpleaños feliz"',
  'Hacer de estatua durante 20 segundos',
  'Narrar lo que pasa como un locutor de fútbol',
  'Reír como villano de película',
  'Saltar en un pie durante 10 segundos',
  'Hacer una pose de superhéroe y decir tu frase',
  'Imitar el sonido de tres animales',
  'Bailar como si estuvieras en cámara lenta',
  'Decir cinco frutas en 5 segundos',
  'Hablar con acento de otro país por un turno',
  'Hacer una reverencia a cada jugador',
  'Inventar una canción de 4 versos sobre el grupo ganador',
  'Hacer mímica de cepillarse los dientes',
  'Dar tres vueltas y decir "¡Charadeando!"',
  'Imitar a un mesero que lleva una bandeja llena',
  'Hacer el baile del robot',
  'Decir algo bonito de cada grupo',
];

/// Lógica de la ruleta de castigos, sin pantallas ni animaciones.
abstract final class Roulette {
  /// Ángulo de cada campo cuando la ruleta tiene [fields] campos.
  static double segment(int fields) => 2 * pi / fields;

  /// Elige al azar el campo donde va a caer la ruleta.
  static int pickField(int fields, Random random) => random.nextInt(fields);

  /// Campo que queda bajo el indicador de arriba cuando la ruleta está
  /// girada [angle] radianes en el sentido del reloj. El campo 0 empieza
  /// arriba y los demás siguen en el sentido del reloj.
  static int fieldAt(double angle, int fields) {
    final under = (-angle) % (2 * pi);
    return (under / segment(fields)).floor() % fields;
  }

  /// Ángulo final para que la ruleta, girando desde [from], quede con el
  /// indicador justo en el centro de [field], después de recorrer al menos
  /// [minDistance] radianes.
  static double stopAngle({
    required double from,
    required int field,
    required int fields,
    required double minDistance,
  }) {
    final turn = 2 * pi;
    // Ángulo (módulo una vuelta) que pone el centro del campo arriba.
    final center = (-(field + 0.5) * segment(fields)) % turn;
    final earliest = from + minDistance;
    final base = earliest - earliest % turn;
    var target = base + center;
    if (target < earliest) target += turn;
    return target;
  }

  /// Frenado: rápido al principio y muy lento al final. [t] va de 0 a 1.
  static double easeOutQuart(double t) {
    final u = 1 - t.clamp(0.0, 1.0);
    return 1 - u * u * u * u;
  }

  /// Grupos con menos puntos, que giran la ruleta. Si todos empatan no hay
  /// castigo y la lista queda vacía.
  static List<int> losers(List<int> scores) {
    if (scores.length < 2) return const [];
    final worst = scores.reduce(min);
    final losers = [
      for (var i = 0; i < scores.length; i++)
        if (scores[i] == worst) i,
    ];
    return losers.length == scores.length ? const [] : losers;
  }

  /// [count] castigos del sistema al azar, sin repetir y sin los de
  /// [exclude].
  static List<String> systemPick(
    int count,
    Random random, {
    Iterable<String> exclude = const [],
    List<String> pool = systemPunishments,
  }) {
    final taken = {for (final e in exclude) _key(e)};
    final options = [
      for (final p in pool)
        if (!taken.contains(_key(p))) p,
    ]..shuffle(random);
    // Si se acaban los distintos, se repiten antes que dejar campos vacíos.
    while (options.length < count) {
      options.addAll([...pool]..shuffle(random));
    }
    return options.take(count).toList();
  }

  /// Castigos de la ruleta en modo "Mezclados": los que escribió el grupo
  /// quedan en su campo y los vacíos los completa el juego, sin repetir.
  static List<String> completeMixed(
    List<String> written,
    int fields,
    Random random, {
    List<String> pool = systemPunishments,
  }) {
    final mine = [
      for (var i = 0; i < fields; i++)
        i < written.length ? written[i].trim() : '',
    ];
    final filled = mine.where((p) => p.isNotEmpty);
    final extra = systemPick(
      mine.where((p) => p.isEmpty).length,
      random,
      exclude: filled,
      pool: pool,
    ).iterator;
    return [
      for (final p in mine)
        if (p.isNotEmpty) p else (extra..moveNext()).current,
    ];
  }

  static String _key(String text) => text.trim().toLowerCase();
}
