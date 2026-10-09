import 'package:flutter/material.dart';

/// Selector numérico con botones de menos y más.
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.format,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final String Function(int value)? format;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              icon: const Icon(Icons.remove),
              onPressed: value - step >= min
                  ? () => onChanged(value - step)
                  : null,
            ),
            SizedBox(
              width: 56,
              child: Text(
                format?.call(value) ?? '$value',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.add),
              onPressed: value + step <= max
                  ? () => onChanged(value + step)
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
