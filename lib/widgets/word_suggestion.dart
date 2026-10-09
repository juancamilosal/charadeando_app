import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

/// Recomienda cuántas palabras escribir por grupo según las rondas y el
/// tiempo por turno, y avisa si las elegidas no alcanzan.
class WordSuggestion extends StatelessWidget {
  const WordSuggestion({super.key, required this.config, required this.onUse});

  final GameConfig config;

  /// Aplica la cantidad sugerida.
  final ValueChanged<int> onUse;

  @override
  Widget build(BuildContext context) {
    final suggested = config.suggestedWordsPerGroup;
    final usable = suggested.clamp(
      GameConfig.minWordsPerGroup,
      GameConfig.maxWordsPerGroup,
    );
    final enough = config.wordsPerGroup >= suggested;
    final covered = config.roundsCovered;
    final coveredText = switch (covered) {
      0 => 'menos de una ronda',
      1 => 'más o menos 1 ronda',
      _ => 'más o menos $covered rondas',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6D6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: AppColors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sugerencia: $suggested palabras por grupo',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${config.rounds} ${config.rounds == 1 ? 'ronda' : 'rondas'} × '
            'unas ${config.wordsPerTurn} palabras por turno de '
            // Espacio que no se corta, para que "90 s" quede en una línea.
            '${config.turnDuration.inSeconds}\u00A0s '
            '(una cada ${GameConfig.secondsPerWord}\u00A0s, más o menos).',
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                enough ? Icons.check_circle : Icons.warning_amber_rounded,
                size: 20,
                color: enough ? AppColors.green : AppColors.orange,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  enough
                      ? 'Con ${config.wordsPerGroup} palabras alcanzan para '
                            'todas las rondas.'
                      : 'Con ${config.wordsPerGroup} palabras alcanzan para '
                            '$coveredText. Si se acaban, ese grupo pierde sus '
                            'turnos.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (suggested > GameConfig.maxWordsPerGroup) ...[
            const SizedBox(height: 6),
            const Text(
              'Son muchas palabras para escribir: prueben con menos rondas o '
              'turnos más cortos.',
            ),
          ],
          if (!enough && config.wordsPerGroup != usable) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.purple),
                icon: const Icon(Icons.auto_fix_high),
                label: Text('Usar $usable palabras'),
                onPressed: () => onUse(usable),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
