import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// La rueda de letras de La Bomba: las letras de la temática en círculo y
/// la bomba en el centro. Quien tiene el celular dice una palabra y toca
/// la letra con que empieza; las usadas se ven apagadas, con un ✓, y ya
/// no se pueden tocar.
class LetterWheel extends StatelessWidget {
  const LetterWheel({
    super.key,
    required this.letters,
    required this.used,
    required this.onTap,
    this.enabled = true,
    this.pulse = false,
  });

  final List<String> letters;
  final Set<String> used;
  final ValueChanged<String> onTap;
  final bool enabled;

  /// La bomba late con cada tic.
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final n = max(letters.length, 1);
        // Las fichas, más pequeñas cuanto más letras haya.
        final tile =
            (size *
                    (n <= 10
                        ? 0.19
                        : n <= 16
                        ? 0.15
                        : 0.125))
                .clamp(36.0, 84.0);
        final radius = size / 2 - tile / 2 - 4;
        return Center(
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              children: [
                // El aro de la rueda.
                Center(
                  child: Container(
                    width: radius * 2,
                    height: radius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 3,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: AnimatedScale(
                    scale: pulse ? 1.12 : 1,
                    duration: const Duration(milliseconds: 90),
                    child: Text(
                      '💣',
                      style: TextStyle(fontSize: radius * 0.75),
                    ),
                  ),
                ),
                for (var i = 0; i < letters.length; i++)
                  Positioned(
                    left:
                        size / 2 +
                        radius * cos(-pi / 2 + i * 2 * pi / n) -
                        tile / 2,
                    top:
                        size / 2 +
                        radius * sin(-pi / 2 + i * 2 * pi / n) -
                        tile / 2,
                    child: _LetterTile(
                      letter: letters[i],
                      size: tile,
                      used: used.contains(letters[i]),
                      onTap: enabled && !used.contains(letters[i])
                          ? () => onTap(letters[i])
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LetterTile extends StatelessWidget {
  const _LetterTile({
    required this.letter,
    required this.size,
    required this.used,
    this.onTap,
  });

  final String letter;
  final double size;
  final bool used;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: !used,
      label: used ? '$letter, usada' : 'Letra $letter',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: used ? 0.45 : 1,
        child: Material(
          color: used ? Colors.white.withValues(alpha: 0.35) : Colors.white,
          shape: const CircleBorder(),
          elevation: used ? 0 : 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    letter,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: size * 0.55,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  if (used)
                    Icon(Icons.check, color: AppColors.green, size: size * 0.7),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
