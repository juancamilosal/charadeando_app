import 'dart:math';

/// Castigos del sistema para la ruleta. Charadeando es un juego familiar
/// (4+): 100 castigos cortos, divertidos y sin humillar a nadie: nada
/// pesado, grosero ni peligroso.
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
  'Inventar una canción de 4 versos sobre el equipo ganador',
  'Hacer mímica de cepillarse los dientes',
  'Dar tres vueltas y decir "¡Charadeando!"',
  'Imitar a un mesero que lleva una bandeja llena',
  'Hacer el baile del robot',
  'Decir algo bonito de cada equipo',
  'Imitar a una gallina poniendo un huevo',
  'Cantar una canción infantil con voz de ópera',
  'Caminar como modelo de pasarela por la sala',
  'Hacer de mimo atrapado en una caja invisible',
  'Decir tu nombre al revés',
  'Contar hasta 20 saltando en un pie',
  'Imitar a un perro que pide comida',
  'Bailar la canción que elija el equipo ganador',
  'Hablar como bebé hasta el siguiente turno',
  'Hacer cinco sentadillas contando en inglés',
  'Decir tres cosas que te hacen feliz',
  'Imitar a un mono durante 10 segundos',
  'Cantar "Los pollitos dicen" con voz grave',
  'Hacer la mejor cara de enojado sin reírse',
  'Imitar a un presentador de noticias',
  'Dar un abrazo de oso a alguien de tu equipo',
  'Decir algo bonito al mayor de los jugadores',
  'Hacer el sonido de un tren durante 10 segundos',
  'Caminar como astronauta en la Luna',
  'Imitar a una bailarina de ballet',
  'Hablar rimando hasta el siguiente turno',
  'Decir cinco colores en 5 segundos',
  'Decir cinco animales en 5 segundos',
  'Hacer la mímica de un pez fuera del agua',
  'Silbar una canción hasta que la adivinen',
  'Imitar a un gato que se despierta',
  'Contar algo divertido que te pasó',
  'Hacer una pose de foto y quedarse 10 segundos',
  'Dar las gracias a cada jugador con voz de robot',
  'Cantar una canción de cuna',
  'Imitar a un pato caminando hasta la puerta',
  'Hacer el baile de la gallina',
  'Decir "Charadeando" con cinco voces distintas',
  'Inventar un saludo secreto con el equipo ganador',
  'Hablar como pirata hasta el siguiente turno',
  'Imitar a un superhéroe volando por la sala',
  'Hacer reír a alguien sin hablar',
  'Decir un trabalenguas con la boca tapada',
  'Imitar a un león que ruge bajito',
  'Hacer de estatua de museo mientras te hablan',
  'Cantar "Feliz cumpleaños" en cámara lenta',
  'Aplaudir 10 veces con los ojos cerrados',
  'Imitar el ruido de una moto que no arranca',
  'Caminar hacia atrás hasta la puerta y volver',
  'Contar una adivinanza a todos',
  'Imitar a un abuelito contando un cuento',
  'Hacer la mímica de manejar un carro de carreras',
  'Decir los días de la semana al revés',
  'Saludar a todos como si fueras de la realeza',
  'Imitar a un elefante con la trompa',
  'Bailar como un espantapájaros',
  'Hacer el sonido de la lluvia con las manos',
  'Hablar sin decir la letra "a" por un turno',
  'Imitar a un chef famoso cocinando',
  'Hacer cinco caras distintas en 10 segundos',
  'Imitar a un caracol muy, muy lento',
  'Cantar tu canción favorita en susurros',
  'Decir tres cualidades de quien tienes a la derecha',
  'Imitar a un mago haciendo un truco',
  'Hacer el saludo de un soldado y marchar',
  'Imitar a una rana saltando tres veces',
  'Contar del 10 al 1 con voz de cohete',
  'Hacer una mini obra de teatro de 10 segundos',
  'Imitar a tu personaje de película favorito',
  'Bailar el trencito con tu equipo',
  'Decir cinco comidas en 5 segundos',
  'Imitar a un búho girando la cabeza',
  'Sonreír sin parar durante 20 segundos',
  'Hacer un brindis imaginario por el equipo ganador',
  'Terminar la ronda con un grito de "¡Viva la familia!"',
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
  /// [minDistance] radianes. Con [direction] negativo gira al revés (en
  /// contra del reloj).
  static double stopAngle({
    required double from,
    required int field,
    required int fields,
    required double minDistance,
    int direction = 1,
  }) {
    final turn = 2 * pi;
    // Ángulo (módulo una vuelta) que pone el centro del campo arriba.
    final center = (-(field + 0.5) * segment(fields)) % turn;
    final earliest = from + direction * minDistance;
    final base = earliest - earliest % turn;
    var target = base + center;
    if (direction >= 0 && target < earliest) target += turn;
    if (direction < 0 && target > earliest) target -= turn;
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

  /// Castigos de la ruleta en modo "Jugadores y app": los que escribió el equipo
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
