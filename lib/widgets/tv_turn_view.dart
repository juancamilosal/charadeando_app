import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'word_card.dart';

/// Turno del Modo TV. El celular se duplica en el televisor, así que esta
/// vista es la que ve todo el grupo: el grupo y la ronda arriba, la palabra
/// en grande, el tiempo y el marcador. Abajo van los botones del juez,
/// grandes para tocarlos sin mirar mucho.
class TvTurnView extends StatelessWidget {
  const TvTurnView({
    super.key,
    required this.word,
    required this.remaining,
    required this.feedback,
    required this.groupName,
    required this.roundLabel,
    required this.groups,
    required this.scores,
    required this.groupIndex,
    required this.wordsLeft,
    required this.onPass,
    required this.onHit,
  });

  static const _hitColors = [AppColors.green, Color(0xFF0E9F55)];
  static const _passColors = [AppColors.orange, AppColors.coral];

  final Word word;
  final Duration remaining;
  final WordOutcome? feedback;
  final String groupName;
  final String roundLabel;
  final List<Group> groups;

  /// Puntajes de cada grupo, con los puntos del turno en curso incluidos.
  final List<int> scores;

  /// Grupo que está jugando.
  final int groupIndex;

  /// Palabras que faltan por adivinar en toda la partida.
  final int wordsLeft;
  final VoidCallback onPass;
  final VoidCallback onHit;

  @override
  Widget build(BuildContext context) {
    final (colors, text) = switch (feedback) {
      WordOutcome.hit => (_hitColors, '¡Correcto!'),
      WordOutcome.pass => (_passColors, 'Paso'),
      null => (AppColors.word, word.text),
    };
    final marking = feedback == null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$roundLabel · '
                          '${WordCard.wordsLeftLabel(wordsLeft)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Turno de $groupName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Timer(remaining: remaining),
                ],
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 96,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _ScoreStrip(
                groups: groups,
                scores: scores,
                groupIndex: groupIndex,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _JudgeButton(
                      label: 'Pasar',
                      icon: Icons.skip_next,
                      color: AppColors.orange,
                      onPressed: marking ? onPass : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _JudgeButton(
                      label: '¡Correcto!',
                      icon: Icons.check_circle,
                      color: AppColors.green,
                      onPressed: marking ? onHit : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Timer extends StatelessWidget {
  const _Timer({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final low = remaining.inSeconds <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: low ? AppColors.yellow : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, color: AppColors.ink),
          const SizedBox(width: 6),
          Text(
            '${remaining.inSeconds}',
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Marcador de todos los grupos en una fila; el que juega va resaltado.
class _ScoreStrip extends StatelessWidget {
  const _ScoreStrip({
    required this.groups,
    required this.scores,
    required this.groupIndex,
  });

  final List<Group> groups;
  final List<int> scores;
  final int groupIndex;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        for (var i = 0; i < groups.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: i == groupIndex
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${groups[i].name}  ${scores[i]}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: i == groupIndex ? AppColors.ink : Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _JudgeButton extends StatelessWidget {
  const _JudgeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      icon: Icon(icon, size: 30),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white70,
        minimumSize: const Size.fromHeight(64),
        textStyle: const TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 26,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: onPressed,
    );
  }
}
