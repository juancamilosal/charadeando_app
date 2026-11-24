import 'package:flutter/material.dart';

import '../theme.dart';
import 'play_background.dart';

/// Número grande de la cuenta regresiva antes de cada turno.
class CountdownView extends StatelessWidget {
  const CountdownView({super.key, required this.value, this.caption});

  final int value;

  /// Un texto arriba del número (en La Bomba, la temática).
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return PlayBackground(
      colors: AppColors.countdown,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (caption case final caption?)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 32,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Text(
                '$value',
                key: ValueKey(value),
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 180,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
