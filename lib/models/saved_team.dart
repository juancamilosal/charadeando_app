import 'package:flutter/material.dart';

import '../theme.dart';

/// Equipo guardado en "Equipos": nombre, color, ícono o emoji, jugadores e
/// historial. Se guarda solo en el celular.
class SavedTeam {
  const SavedTeam({
    required this.id,
    required this.name,
    this.colorIndex = 0,
    this.iconKey,
    this.emoji,
    this.players = const [],
    this.played = 0,
    this.wins = 0,
    this.best = 0,
  });

  factory SavedTeam.fromJson(Map<String, dynamic> json) => SavedTeam(
    id: json['id'] as String? ?? '',
    name: json['nombre'] as String? ?? '',
    colorIndex: (json['color'] as num?)?.toInt() ?? 0,
    iconKey: json['icono'] as String?,
    emoji: json['emoji'] as String?,
    players: [
      for (final p in json['jugadores'] as List? ?? const [])
        if (p is String && p.trim().isNotEmpty) p.trim(),
    ],
    played: (json['partidas'] as num?)?.toInt() ?? 0,
    wins: (json['victorias'] as num?)?.toInt() ?? 0,
    best: (json['mejorPuntaje'] as num?)?.toInt() ?? 0,
  );

  static const maxNameLength = 24;
  static const maxPlayerLength = 24;

  /// Colores que se pueden elegir, de la paleta de la app.
  static const colors = [
    AppColors.purple,
    AppColors.magenta,
    AppColors.coral,
    AppColors.orange,
    AppColors.yellow,
    AppColors.green,
    AppColors.turquoise,
    AppColors.blue,
    AppColors.navy,
    AppColors.indigo,
  ];

  /// Íconos que se pueden elegir, por clave (lo que se guarda).
  static const icons = <String, IconData>{
    'groups': Icons.groups,
    'star': Icons.star,
    'bolt': Icons.bolt,
    'fire': Icons.local_fire_department,
    'rocket': Icons.rocket_launch,
    'crown': Icons.workspace_premium,
    'pet': Icons.pets,
    'heart': Icons.favorite,
    'sports': Icons.sports_soccer,
    'music': Icons.music_note,
  };

  /// Emojis que se pueden elegir.
  static const emojis = [
    '🦁', '🐯', '🦅', '🐬', '🐺', '🦊', '🐼', '🦄', //
    '🔥', '⚡', '⭐', '🚀', '👑', '🎉', '🍕', '⚽',
  ];

  final String id;
  final String name;
  final int colorIndex;

  /// El ícono elegido, o null si es un emoji.
  final String? iconKey;

  /// El emoji elegido, o null si es un ícono.
  final String? emoji;

  /// Nombres de quienes forman el equipo (opcional).
  final List<String> players;

  /// Historial: partidas jugadas, victorias y mejor puntaje.
  final int played;
  final int wins;
  final int best;

  Color get color => colors[colorIndex % colors.length];

  /// Texto e íconos sobre el color del equipo.
  Color get onColor => color == AppColors.yellow ? AppColors.ink : Colors.white;

  IconData get icon => icons[iconKey] ?? Icons.groups;

  /// "3 partidas · 1 victoria · Mejor: 12".
  String get historyLabel {
    if (played == 0) return 'Sin partidas todavía';
    return '$played ${played == 1 ? 'partida' : 'partidas'} · '
        '$wins ${wins == 1 ? 'victoria' : 'victorias'} · Mejor: $best';
  }

  SavedTeam copyWith({
    String? name,
    int? colorIndex,
    String? iconKey,
    String? emoji,
    bool clearIcon = false,
    bool clearEmoji = false,
    List<String>? players,
    int? played,
    int? wins,
    int? best,
  }) => SavedTeam(
    id: id,
    name: name ?? this.name,
    colorIndex: colorIndex ?? this.colorIndex,
    iconKey: clearIcon ? null : iconKey ?? this.iconKey,
    emoji: clearEmoji ? null : emoji ?? this.emoji,
    players: players ?? this.players,
    played: played ?? this.played,
    wins: wins ?? this.wins,
    best: best ?? this.best,
  );

  /// Suma una partida al historial: [won] si ganó (en empate no cuenta) y
  /// [score] para el mejor puntaje.
  SavedTeam withGame({required int score, required bool won}) => copyWith(
    played: played + 1,
    wins: wins + (won ? 1 : 0),
    best: score > best ? score : best,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': name,
    'color': colorIndex,
    'icono': iconKey,
    'emoji': emoji,
    'jugadores': players,
    'partidas': played,
    'victorias': wins,
    'mejorPuntaje': best,
  };

  @override
  bool operator ==(Object other) => other is SavedTeam && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
