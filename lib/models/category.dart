import 'package:flutter/material.dart';

import '../theme.dart';

/// Secciones de la pantalla de categorías, en el orden en que se ven.
enum CategorySection {
  classics('Clásicos', [
    Color(0xFF127A45),
    Color(0xFF18A85C),
    Color(0xFF2BC273),
  ]),
  entertainment('Entretenimiento', [
    Color(0xFF1F4FD1),
    Color(0xFF2F80FF),
    Color(0xFF3A9BF0),
  ]),
  culture('Cultura general', [
    Color(0xFF0B6E77),
    Color(0xFF0E8C96),
    Color(0xFF14A3A8),
  ]),
  sports('Deportes', [Color(0xFF1B2F73), Color(0xFF1E3A8A), Color(0xFF2B4BA8)]),
  special('Especiales', [
    Color(0xFFB81D2E),
    AppColors.red,
    Color(0xFFE84855),
  ], note: 'Solo por temporada');

  const CategorySection(this.title, this.shades, {this.note});

  final String title;

  /// Tonos de las tarjetas de la sección en la pantalla de categorías: un
  /// mismo color, del más oscuro al más claro, que se alternan en orden.
  /// Así no se ve tan cargada y cada tarjeta se distingue de la de al lado.
  /// En el resto de la app cada categoría usa su propio color.
  final List<Color> shades;

  /// El tono de la tarjeta en la posición [index] de la sección.
  Color shade(int index) => shades[index % shades.length];

  /// Texto a la derecha del título en vez de cuántas categorías tiene.
  final String? note;
}

/// Temporada de una categoría especial: del día [start] al día [end]
/// (mes y día, ambos incluidos), todos los años. Puede pasar de un año al
/// siguiente, como Navidad (del 1 de diciembre al 6 de enero).
class Season {
  const Season(this.start, this.end);

  /// Mes y día en que empieza.
  final (int month, int day) start;

  /// Mes y día en que termina.
  final (int month, int day) end;

  bool contains(DateTime date) {
    int key((int, int) md) => md.$1 * 100 + md.$2;
    final today = date.month * 100 + date.day;
    final from = key(start);
    final to = key(end);
    return from <= to
        ? today >= from && today <= to
        : today >= from || today <= to;
  }
}

/// Categorías de palabras. En "Libre" los grupos escriben las palabras o
/// se descargan frases de la categoría LIBRE; las demás descargan palabras
/// de su categoría en Directus. Van en el orden de la pantalla: Libre y
/// después cada sección (Clásicos, Entretenimiento, Cultura general,
/// Deportes y Especiales).
enum GameCategory {
  free(
    'Libre',
    'Sus palabras o las nuestras',
    Icons.edit_note,
    AppColors.blue,
    'LIBRE',
    'Palabra',
  ),

  // Clásicos.
  animals(
    'Animales',
    'Del perro a la jirafa',
    Icons.pets,
    AppColors.green,
    'ANIMALES',
    'Animal',
    section: CategorySection.classics,
  ),
  food(
    'Comida',
    'Para chuparse los dedos',
    Icons.lunch_dining,
    AppColors.tomato,
    'COMIDA',
    'Comida',
    section: CategorySection.classics,
  ),
  objects(
    'Objetos',
    'Cosas de todos los días',
    Icons.key,
    AppColors.coral,
    'OBJETOS',
    'Objeto',
    section: CategorySection.classics,
  ),
  professions(
    'Profesiones',
    '¿A qué te dedicas?',
    Icons.work,
    AppColors.blue,
    'PROFESIONES',
    'Profesión',
    section: CategorySection.classics,
  ),
  actions(
    'Acciones',
    '¡A actuar!',
    Icons.directions_run,
    AppColors.teal,
    'ACCIONES',
    'Acción',
    section: CategorySection.classics,
  ),

  // Entretenimiento.
  movies(
    'Películas',
    'Clásicos y estrenos',
    Icons.movie,
    AppColors.teal,
    'PELICULAS',
    'Película',
    section: CategorySection.entertainment,
  ),
  seriesNovels(
    'Series y novelas',
    'Para los que no se pierden un capítulo',
    Icons.live_tv,
    AppColors.pink,
    'SERIES_NOVELAS',
    'Serie o novela',
    section: CategorySection.entertainment,
  ),
  characters(
    'Personajes',
    'De películas, libros y juegos',
    Icons.face_retouching_natural,
    AppColors.purple,
    'PERSONAJES',
    'Personaje',
    section: CategorySection.entertainment,
  ),
  superheroes(
    'Superhéroes',
    'Con capa o sin capa',
    Icons.bolt,
    AppColors.blue,
    'SUPERHEROES',
    'Superhéroe',
    section: CategorySection.entertainment,
  ),
  cartoons(
    'Dibujos animados',
    'Los de ayer y los de hoy',
    Icons.child_care,
    AppColors.yellow,
    'DIBUJOS_ANIMADOS',
    'Dibujo animado',
    section: CategorySection.entertainment,
  ),
  anime(
    'Anime',
    'Goku, Naruto y compañía',
    Icons.catching_pokemon,
    AppColors.coral,
    'ANIME',
    'Anime',
    section: CategorySection.entertainment,
  ),
  videogames(
    'Videojuegos',
    'Del Pac-Man al Fortnite',
    Icons.sports_esports,
    AppColors.indigo,
    'VIDEOJUEGOS',
    'Videojuego',
    section: CategorySection.entertainment,
  ),
  music(
    'Música y canciones',
    'Para cantar y bailar',
    Icons.mic,
    AppColors.magenta,
    'MUSICA',
    'Canción o artista',
    section: CategorySection.entertainment,
  ),
  celebrities(
    'Celebridades',
    'Famosos de todo tipo',
    Icons.star,
    AppColors.orange,
    'CELEBRIDADES',
    'Famoso',
    section: CategorySection.entertainment,
  ),

  // Cultura general.
  geography(
    'Geografía',
    'Países, ciudades, ríos y más',
    Icons.public,
    AppColors.indigo,
    'GEOGRAFIA',
    'Geografía',
    section: CategorySection.culture,
  ),
  places(
    'Lugares',
    'De la casa al fin del mundo',
    Icons.place,
    AppColors.forest,
    'LUGARES',
    'Lugar',
    section: CategorySection.culture,
  ),
  historicalFigures(
    'Personajes históricos',
    'Los que hicieron historia',
    Icons.account_balance,
    AppColors.brown,
    'PERSONAJES_HISTORICOS',
    'Personaje histórico',
    section: CategorySection.culture,
  ),
  sayings(
    'Dichos y refranes',
    'Como decía la abuela',
    Icons.chat_bubble,
    AppColors.orange,
    'DICHOS_REFRANES',
    'Dicho o refrán',
    section: CategorySection.culture,
  ),
  brands(
    'Marcas',
    'Las que todos conocen',
    Icons.local_offer,
    AppColors.blue,
    'MARCAS',
    'Marca',
    section: CategorySection.culture,
  ),

  // Deportes.
  sports(
    'Deportes',
    'A moverse',
    Icons.sports_basketball,
    AppColors.navy,
    'DEPORTES',
    'Deporte',
    section: CategorySection.sports,
  ),
  soccerTeams(
    'Equipos de fútbol',
    'Para los futboleros',
    Icons.sports_soccer,
    AppColors.purple,
    'EQUIPOS_FUTBOL',
    'Equipo de fútbol',
    section: CategorySection.sports,
  ),
  footballers(
    'Futbolistas',
    'Los cracks de la cancha',
    Icons.sports_soccer,
    AppColors.green,
    'FUTBOLISTAS',
    'Futbolista',
    section: CategorySection.sports,
  ),
  athletes(
    'Deportistas',
    'Leyendas de todos los deportes',
    Icons.emoji_events,
    AppColors.orange,
    'DEPORTISTAS',
    'Deportista',
    section: CategorySection.sports,
  ),

  // Especiales: solo se ven en su temporada.
  vacations(
    'Vacaciones',
    'Playa, viajes y descanso',
    Icons.beach_access,
    AppColors.turquoise,
    'VACACIONES',
    'Palabra de vacaciones',
    section: CategorySection.special,
    season: Season((6, 15), (7, 31)),
  ),
  halloween(
    'Halloween',
    'Disfraces, sustos y dulces',
    Icons.nightlight_round,
    AppColors.orange,
    'HALLOWEEN',
    'Palabra de Halloween',
    section: CategorySection.special,
    season: Season((10, 1), (10, 31)),
  ),
  christmas(
    'Navidad',
    'Novenas, regalos y buñuelos',
    Icons.park,
    AppColors.red,
    'NAVIDAD',
    'Palabra navideña',
    section: CategorySection.special,
    season: Season((12, 1), (1, 6)),
  );

  const GameCategory(
    this.label,
    this.description,
    this.icon,
    this.color,
    this.code,
    this.singular, {
    this.section,
    this.season,
    // Por ahora ninguna categoría los usa (todas tienen palabras y, en
    // desarrollo, ninguna se marca como nueva), pero se dejan para las que
    // vengan.
    // ignore: unused_element_parameter
    this.isNew = false,
    // ignore: unused_element_parameter
    this.available = true,
  });

  final String label;

  /// Frase corta. Por ahora las tarjetas no la muestran.
  final String description;
  final IconData icon;
  final Color color;

  /// Valor del campo `categoria` en Directus.
  final String code;

  /// Nombre de una sola palabra de la categoría ("Película"), para mostrar
  /// arriba de la palabra en una partida con varias categorías.
  final String singular;

  /// Sección de la pantalla de categorías; null solo en Libre, que va
  /// arriba, aparte.
  final CategorySection? section;

  /// Las especiales solo se ven en su temporada; las demás, siempre.
  final Season? season;

  /// Lleva la etiqueta "Nueva" en su tarjeta. Se quita cuando deje de serlo.
  final bool isNew;

  /// Falso mientras no tenga palabras en Directus: se ve con "Pronto" y no
  /// se puede jugar ni combinar. Se cambia a verdadero cuando se carguen.
  final bool available;

  /// Cuántas categorías de cada sección son gratis: las primeras, en el
  /// orden de la pantalla. Las demás son de pago.
  static const freePerSection = 2;

  /// Categorías de pago: se juegan comprándolas, con Todo Charadeando o con
  /// un código. Son todas menos las [freePerSection] primeras de cada
  /// sección (Libre siempre es gratis).
  static final Set<GameCategory> paid = {
    for (final section in CategorySection.values)
      ...values.where((c) => c.section == section).skip(freePerSection),
  };

  /// Se desbloquea con Premium (o con un código).
  bool get premium => paid.contains(this);

  /// Color del dibujo y del texto sobre el color de la categoría.
  Color get onColor => color == AppColors.yellow ? AppColors.ink : Colors.white;

  /// Si se muestra en [date]: las especiales, solo en su temporada (o
  /// siempre, con [allSeasons], para probarlas).
  bool shownOn(DateTime date, {bool allSeasons = false}) =>
      allSeasons || (season?.contains(date) ?? true);

  static GameCategory? byCode(String? code) {
    for (final c in values) {
      if (c.code == code) return c;
    }
    return null;
  }

  /// Categorías con palabras del backend, sin contar "Libre".
  static List<GameCategory> get themed =>
      values.where((c) => c != GameCategory.free).toList();

  /// Las categorías de [section] que se ven en [date], en su orden.
  static List<GameCategory> inSection(
    CategorySection section,
    DateTime date, {
    bool allSeasons = false,
  }) => [
    for (final c in values)
      if (c.section == section && c.shownOn(date, allSeasons: allSeasons)) c,
  ];

  /// Las secciones que tienen algo que mostrar en [date], cada una con sus
  /// categorías. Especiales no sale fuera de temporada (salvo con
  /// [allSeasons]).
  static List<(CategorySection, List<GameCategory>)> sectionsOn(
    DateTime date, {
    bool allSeasons = false,
  }) => [
    for (final s in CategorySection.values)
      if (inSection(s, date, allSeasons: allSeasons) case final list
          when list.isNotEmpty)
        (s, list),
  ];
}
