import 'package:flutter/material.dart';

import '../theme.dart';

/// "¿Cómo van a jugar?": sin grupos o en grupos, como dos botones de
/// radio con forma de píldora. La opción elegida va en blanco con el texto
/// morado; la otra, transparente con borde blanco.
class PlayModeSelector extends StatelessWidget {
  const PlayModeSelector({
    super.key,
    required this.inGroups,
    required this.onChanged,
  });

  final bool inGroups;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(bool value, String label) {
      final on = value == inGroups;
      final color = on ? AppColors.purple : Colors.white;
      return Expanded(
        child: Semantics(
          inMutuallyExclusiveGroup: true,
          checked: on,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: on ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    on ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 20,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  // Con letra grande en el celular, se achica para caber.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            option(false, 'Sin grupos'),
            const SizedBox(width: 10),
            option(true, 'En grupos'),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          inGroups
              ? 'Cada grupo con su nombre y sus puntos.'
              : 'Solo salen las palabras: ustedes se organizan.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
