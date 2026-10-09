import 'package:flutter/material.dart';

import '../theme.dart';

/// Selector numérico con botones circulares de menos y más.
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.format,
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final String Function(int value)? format;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(
          Icons.remove,
          value - step >= min,
          () => onChanged(value - step),
        ),
        SizedBox(
          width: 62,
          child: Text(
            format?.call(value) ?? '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.purple,
            ),
          ),
        ),
        _button(Icons.add, value + step <= max, () => onChanged(value + step)),
      ],
    );
  }

  Widget _button(IconData icon, bool enabled, VoidCallback onPressed) {
    return IconButton.outlined(
      icon: Icon(icon, size: 20),
      color: AppColors.purple,
      style: IconButton.styleFrom(
        side: BorderSide(
          color: enabled ? AppColors.purple : const Color(0xFFD9CCF2),
          width: 1.5,
        ),
      ),
      onPressed: enabled ? onPressed : null,
    );
  }
}
