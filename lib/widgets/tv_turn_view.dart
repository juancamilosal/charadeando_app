import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'end_game_dialog.dart';

/// Turno del Modo TV. El celular se duplica en el televisor, así que esta
/// vista es la que ve todo el grupo. Es sencilla a propósito: el turno del
/// grupo y el tiempo arriba, la palabra en grande y abajo los botones del
/// juez, grandes para tocarlos sin mirar mucho.
class TvTurnView extends StatelessWidget {
  const TvTurnView({
    super.key,
    required this.word,
    required this.remaining,
    required this.feedback,
    required this.title,
    required this.onPass,
    required this.onHit,
    this.onEndGame,
  });

  static const _hitColors = [AppColors.green, Color(0xFF0E9F55)];
  static const _passColors = [AppColors.orange, AppColors.coral];

  final Word word;
  final Duration remaining;
  final WordOutcome? feedback;

  /// "Turno de Los Tigres", o "¡A jugar!" sin grupos.
  final String title;
  final VoidCallback onPass;
  final VoidCallback onHit;

  /// "Finalizar juego", para terminar la partida sin esperar el turno.
  final VoidCallback? onEndGame;

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
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (onEndGame != null) ...[
                    // En pantallas angostas solo la bandera, para que
                    // quepan el grupo y el tiempo.
                    if (MediaQuery.sizeOf(context).width < 600)
                      IconButton(
                        icon: const Icon(Icons.flag, color: Colors.white),
                        tooltip: 'Finalizar juego',
                        onPressed: onEndGame,
                      )
                    else
                      EndGameButton(onPressed: onEndGame, compact: true),
                    const SizedBox(width: 8),
                  ],
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
