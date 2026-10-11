/// Un video de "Mis videos". El video vive en la galería del celular; aquí
/// se guarda solo su referencia y los datos del turno.
class SavedVideo {
  const SavedVideo({
    required this.assetId,
    required this.savedAt,
    required this.category,
    required this.round,
    required this.points,
    this.group,
    this.groups = const [],
    this.scores = const [],
  });

  factory SavedVideo.fromJson(Map<String, dynamic> json) => SavedVideo(
    assetId: json['id'] as String,
    savedAt:
        DateTime.tryParse(json['fecha'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    category: json['categoria'] as String? ?? '',
    round: (json['ronda'] as num?)?.toInt() ?? 1,
    points: (json['puntos'] as num?)?.toInt() ?? 0,
    group: json['grupo'] as String?,
    groups: [
      for (final g in json['grupos'] as List? ?? const [])
        if (g is String) g,
    ],
    scores: [
      for (final s in json['puntajes'] as List? ?? const [])
        if (s is num) s.toInt(),
    ],
  );

  /// Identificador del video en la galería.
  final String assetId;
  final DateTime savedAt;

  /// Nombre de la categoría que se jugaba.
  final String category;
  final int round;

  /// Puntos del turno del video.
  final int points;

  /// Grupo que jugó el turno, o null si se jugó sin grupos.
  final String? group;

  /// Nombres de todos los grupos y sus puntajes al terminar el turno.
  final List<String> groups;
  final List<int> scores;

  Map<String, dynamic> toJson() => {
    'id': assetId,
    'fecha': savedAt.toIso8601String(),
    'categoria': category,
    'ronda': round,
    'puntos': points,
    'grupo': group,
    'grupos': groups,
    'puntajes': scores,
  };

  /// "Los Tigres · +5 puntos", o "+5 puntos" sin grupos.
  String get title {
    final pts = '+$points ${points == 1 ? 'punto' : 'puntos'}';
    final name = group;
    return name == null || name.isEmpty ? pts : '$name · $pts';
  }

  /// "Los Tigres 12 · Las Águilas 9".
  String get scoreLine => [
    for (var i = 0; i < groups.length && i < scores.length; i++)
      '${groups[i]} ${scores[i]}',
  ].join(' · ');

  @override
  bool operator ==(Object other) =>
      other is SavedVideo && other.assetId == assetId;

  @override
  int get hashCode => assetId.hashCode;
}
