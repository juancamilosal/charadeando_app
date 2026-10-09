import 'package:flutter/material.dart';

import '../models/models.dart';

/// Tabla de puntajes de todos los grupos, ordenada de mayor a menor.
class Scoreboard extends StatelessWidget {
  const Scoreboard({
    super.key,
    required this.groups,
    required this.scores,
    this.highlight,
  });

  final List<Group> groups;
  final List<int> scores;

  /// Índice del grupo a resaltar, por ejemplo el que acaba de jugar.
  final int? highlight;

  /// Posición del grupo; los empatados comparten la misma.
  int _rank(int i) => 1 + scores.where((s) => s > scores[i]).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = List.generate(groups.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final i in order)
              ListTile(
                dense: true,
                selected: i == highlight,
                leading: CircleAvatar(radius: 14, child: Text('${_rank(i)}')),
                title: Text(groups[i].name),
                trailing: Text(
                  '${scores[i]} pts',
                  style: theme.textTheme.titleMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
