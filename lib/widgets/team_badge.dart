import 'package:flutter/material.dart';

import '../models/models.dart';

/// El distintivo de un equipo: un círculo de su color con su emoji o su
/// ícono.
class TeamBadge extends StatelessWidget {
  const TeamBadge({super.key, required this.team, this.size = 48});

  final SavedTeam team;
  final double size;

  @override
  Widget build(BuildContext context) {
    final emoji = team.emoji;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: team.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: emoji != null
          ? Text(emoji, style: TextStyle(fontSize: size * 0.5))
          : Icon(team.icon, color: team.onColor, size: size * 0.55),
    );
  }
}
