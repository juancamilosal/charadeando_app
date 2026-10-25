/// Cómo se marcan los aciertos y los pases durante el turno, fuera del
/// Modo TV (ahí el juez marca con sus botones).
enum PlayController {
  /// Inclinar el celular: abajo es acierto y arriba es pasar.
  tilt('Inclinación'),

  /// Tocar la pantalla: la mitad derecha es acierto y la izquierda, pasar.
  touch('Toque');

  const PlayController(this.label);

  final String label;
}

/// Ajustes de la app. Se guardan en el celular y se aplican desde que abre.
class AppSettings {
  const AppSettings({
    this.music = true,
    this.sounds = true,
    this.vibration = true,
    this.controller = PlayController.tilt,
    this.shareData = true,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    music: json['musica'] as bool? ?? true,
    sounds: json['sonidos'] as bool? ?? true,
    vibration: json['vibracion'] as bool? ?? true,
    controller: PlayController.values.firstWhere(
      (c) => c.name == json['controlador'],
      orElse: () => PlayController.tilt,
    ),
    shareData: json['compartirDatos'] as bool? ?? true,
  );

  final bool music;

  /// Efectos de sonido.
  final bool sounds;
  final bool vibration;

  final PlayController controller;

  /// "Enviar datos anónimos": los errores a Crashlytics y
  /// las estadísticas de las partidas a Directus.
  final bool shareData;

  AppSettings copyWith({
    bool? music,
    bool? sounds,
    bool? vibration,
    PlayController? controller,
    bool? shareData,
  }) => AppSettings(
    music: music ?? this.music,
    sounds: sounds ?? this.sounds,
    vibration: vibration ?? this.vibration,
    controller: controller ?? this.controller,
    shareData: shareData ?? this.shareData,
  );

  Map<String, dynamic> toJson() => {
    'musica': music,
    'sonidos': sounds,
    'vibracion': vibration,
    'controlador': controller.name,
    'compartirDatos': shareData,
  };
}
