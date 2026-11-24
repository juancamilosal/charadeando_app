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
        final width = constraints.maxWidth;
        final height = min(constraints.maxHeight, width * 1.45);
        final n = max(letters.length, 1);
        // Un óvalo que aprovecha el alto. Las fichas, del tamaño que quepa
        // sin tocarse: el 78 % del espacio que le toca a cada una.
        var tile = 60.0;
        var points = <Offset>[];
        for (var i = 0; i < 3; i++) {
          final rx = width / 2 - tile / 2 - 4;
          final ry = height / 2 - tile / 2 - 4;
          final placed = _evenlySpaced(rx, ry, n);
          points = placed.points;
          tile = (placed.step * 0.78).clamp(30.0, 84.0);
        }
        final rx = width / 2 - tile / 2 - 4;
        final ry = height / 2 - tile / 2 - 4;
        points = _evenlySpaced(rx, ry, n).points;
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                // El aro de la rueda.
                Center(
                  child: Container(
                    width: rx * 2,
                    height: ry * 2,
                    decoration: ShapeDecoration(
                      shape: OvalBorder(
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 3,
                        ),
                      ),
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Center(
                  child: AnimatedScale(
                    scale: pulse ? 1.12 : 1,
                    duration: const Duration(milliseconds: 90),
                    child: Text(
                      '💣',
                      style: TextStyle(fontSize: min(rx, ry) * 0.7),
                    ),
                  ),
                ),
                for (var i = 0; i < letters.length; i++)
                  Positioned(
                    left: width / 2 + points[i].dx - tile / 2,
                    top: height / 2 + points[i].dy - tile / 2,
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

/// [n] puntos sobre el óvalo de radios [rx] y [ry], separados por la misma
/// distancia a lo largo del borde (con ángulos iguales se amontonan en las
/// puntas). El primero queda arriba, en el centro. También da la distancia
/// entre uno y otro.
({List<Offset> points, double step}) _evenlySpaced(
  double rx,
  double ry,
  int n,
) {
  const samples = 720;
  Offset at(int k) {
    final angle = -pi / 2 + k * 2 * pi / samples;
    return Offset(rx * cos(angle), ry * sin(angle));
  }

  final lengths = <double>[0];
  for (var k = 1; k <= samples; k++) {
    lengths.add(lengths.last + (at(k) - at(k - 1)).distance);
  }
  final step = lengths.last / n;
  final points = <Offset>[];
  var k = 0;
  for (var i = 0; i < n; i++) {
    final target = i * step;
    while (k < samples && lengths[k + 1] < target) {
      k++;
    }
    final span = lengths[k + 1] - lengths[k];
    final t = span == 0 ? 0.0 : (target - lengths[k]) / span;
    points.add(Offset.lerp(at(k), at(k + 1), t)!);
  }
  return (points: points, step: step);
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
