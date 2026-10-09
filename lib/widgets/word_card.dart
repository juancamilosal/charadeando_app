import 'package:flutter/material.dart';

import '../models/models.dart';

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

  static const _hitColor = Color(0xFF2E7D32);
  static const _passColor = Color(0xFFEF6C00);

  final Word word;
  final Duration remaining;
  final WordOutcome? feedback;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground, text) = switch (feedback) {
      WordOutcome.hit => (_hitColor, Colors.white, '¡Correcto!'),
      WordOutcome.pass => (_passColor, Colors.white, 'Paso'),
      null => (
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
        word.text,
      ),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      color: background,
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
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 96,
                      fontWeight: FontWeight.w900,
                      color: foreground,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 16,
              child: Text(
                '${remaining.inSeconds}',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.bold,
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
