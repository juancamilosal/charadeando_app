import 'package:flutter/material.dart';

import '../theme.dart';
import 'play_background.dart';

/// Número grande de la cuenta regresiva antes de cada turno.
class CountdownView extends StatelessWidget {
  const CountdownView({super.key, required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return PlayBackground(
      colors: AppColors.countdown,
      child: Center(
        child: AnimatedSwitcher(
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
      ),
    );
  }
}
