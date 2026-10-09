import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

/// Tabla de puntajes de todos los grupos, ordenada de mayor a menor.
class Scoreboard extends StatelessWidget {
  const Scoreboard({
    super.key,
    required this.groups,
    required this.scores,
    this.highlight,
  });

  /// Colores de las medallas: oro, plata y bronce.
  static const _medals = [
    AppColors.yellow,
    Color(0xFFC9D1E0),
    Color(0xFFE8A26B),
  ];

  final List<Group> groups;
  final List<int> scores;

  /// Índice del grupo a resaltar, por ejemplo el que acaba de jugar.
  final int? highlight;

  /// Posición del grupo; los empatados comparten la misma.
  int _rank(int i) => 1 + scores.where((s) => s > scores[i]).length;

  @override
  Widget build(BuildContext context) {
    final order = List.generate(groups.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (final i in order) _row(i)],
        ),
      ),
    );
  }

  Widget _row(int i) {
    final rank = _rank(i);
    final highlighted = i == highlight;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFF1E8FF) : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: rank <= _medals.length
              ? _medals[rank - 1]
              : const Color(0xFFEDE7F6),
          foregroundColor: AppColors.ink,
          child: Text(
            '$rank',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(
          groups[i].name,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        trailing: Text(
          '${scores[i]} pts',
          style: const TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.purple,
          ),
        ),
      ),
    );
  }
}
