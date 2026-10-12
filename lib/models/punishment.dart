/// De dónde salen los castigos de la ruleta.
enum PunishmentSource {
  own(
    'Los escriben los jugadores',
    'Ustedes escriben un castigo en cada campo.',
  ),
  system(
    'Los pone la app',
    'La app elige castigos divertidos para todo público.',
  ),
  mixed(
    'Jugadores y app',
    'Escriban los que quieran; la app completa los vacíos.',
  );

  const PunishmentSource(this.label, this.hint);

  final String label;

  /// Qué pasa con esta opción, debajo del nombre.
  final String hint;

  /// Si el grupo escribe castigos con este origen.
  bool get written => this != PunishmentSource.system;
}

/// Ruleta de castigos configurada: los castigos de cada campo, en orden.
/// Se guarda en el celular y la usa también el final de la partida.
class RouletteSetup {
  const RouletteSetup({
    required this.source,
    required this.punishments,
    this.written = const [],
  });

  factory RouletteSetup.fromJson(Map<String, dynamic> json) => RouletteSetup(
    source: PunishmentSource.values.firstWhere(
      (s) => s.name == json['origen'],
      orElse: () => PunishmentSource.system,
    ),
    punishments: [
      for (final p in json['castigos'] as List? ?? const [])
        if (p is String) p,
    ],
    written: [
      for (final p in json['escritos'] as List? ?? const [])
        if (p is String) p,
    ],
  );

  static const minFields = 2;
  static const maxFields = 10;

  final PunishmentSource source;

  /// Un castigo por campo de la ruleta.
  final List<String> punishments;

  /// Lo que escribió el grupo en cada campo (vacío si lo pone el juego),
  /// para mostrarlo otra vez al editar la ruleta.
  final List<String> written;

  int get fields => punishments.length;

  Map<String, dynamic> toJson() => {
    'origen': source.name,
    'castigos': punishments,
    'escritos': written,
  };
}
