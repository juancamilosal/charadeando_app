import 'package:flutter/material.dart';

/// Número grande de la cuenta regresiva antes de cada turno.
class CountdownView extends StatelessWidget {
  const CountdownView({super.key, required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.primary,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Text(
            '$value',
            key: ValueKey(value),
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 160,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
