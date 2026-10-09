import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

/// Advierte, con el cálculo, cuando las palabras elegidas no alcanzan para
/// todas las rondas. Si alcanzan, no muestra nada.
class WordsWarning extends StatelessWidget {
  const WordsWarning({super.key, required this.config});

  final GameConfig config;

  @override
  Widget build(BuildContext context) {
    final needed = config.wordsNeededPerGroup;
    if (config.wordsPerGroup >= needed) return const SizedBox.shrink();

    final rounds = config.rounds;
    final covered = switch (config.roundsCovered) {
      0 => 'menos de una ronda',
      1 => 'más o menos 1 ronda',
      final n => 'más o menos $n rondas',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'En $rounds ${rounds == 1 ? 'ronda' : 'rondas'} de '
              '${config.turnDuration.inSeconds} s, cada grupo resuelve '
              'unas $needed palabras (más o menos una cada '
              '${GameConfig.secondsPerWord} s). Con '
              '${config.wordsPerGroup} alcanzan para $covered; si se '
              'acaban, ese grupo pierde sus turnos.',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
