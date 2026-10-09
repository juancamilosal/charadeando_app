import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

/// Explica cuántas palabras conviene escribir según las rondas y el tiempo
/// por turno.
class WordSuggestion extends StatelessWidget {
  const WordSuggestion({super.key, required this.config});

  final GameConfig config;

  @override
  Widget build(BuildContext context) {
    final perGroup = config.suggestedWordsPerGroup;
    final total = perGroup * config.groupCount;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6D6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, color: AppColors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sugerencia: unas $perGroup palabras por grupo',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mientras más rondas y más tiempo por turno, más palabras '
                  'se juegan. Cada grupo resuelve más o menos una palabra '
                  'cada ${GameConfig.secondsPerWord} segundos, así que '
                  'en ${config.rounds} '
                  '${config.rounds == 1 ? 'ronda' : 'rondas'} de '
                  '${config.turnDuration.inSeconds} s cada grupo usa '
                  'unas $perGroup palabras ($total entre los '
                  '${config.groupCount} grupos). Si se acaban, ese grupo '
                  'pierde sus turnos.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
