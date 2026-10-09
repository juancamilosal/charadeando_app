import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

/// Lo que ven los demás mientras el jugador tiene el celular en la frente:
/// la palabra en grande, el tiempo restante y el resultado de cada palabra.
class WordCard extends StatelessWidget {
  const WordCard({
    super.key,
    required this.word,
    required this.remaining,
    required this.feedback,
    required this.recording,
  });

  static const _hitColors = [AppColors.green, Color(0xFF0E9F55)];
  static const _passColors = [AppColors.orange, AppColors.coral];

  final Word word;
  final Duration remaining;
  final WordOutcome? feedback;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    final (colors, text) = switch (feedback) {
      WordOutcome.hit => (_hitColors, '¡Correcto!'),
      WordOutcome.pass => (_passColors, 'Paso'),
      null => (AppColors.word, word.text),
    };
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
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 100,
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
            Positioned(
              top: 12,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${remaining.inSeconds}',
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            if (recording)
              const Positioned(
                top: 20,
                left: 16,
                child: Icon(Icons.fiber_manual_record, color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}
