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
    this.seconds,
    this.title,
  });

  final List<String> letters;
  final Set<String> used;
  final ValueChanged<String> onTap;
  final bool enabled;

  /// La bomba late con cada tic.
  final bool pulse;

  /// En el modo de 11 segundos: los que le quedan a quien tiene el
  /// celular, encima de la bomba. Null en el modo secreto.
  final int? seconds;

  /// La temática, dentro del círculo, encima de la bomba.
  final String? title;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = min(constraints.maxHeight, width * 1.45);
        final n = max(letters.length, 1);
        // Un óvalo que aprovecha el alto. Las fichas, del tamaño que quepa
        // sin tocarse: el 86 % del espacio que le toca a cada una.
        var tile = 60.0;
        var points = <Offset>[];
        for (var i = 0; i < 3; i++) {
          final rx = width / 2 - tile / 2 - 4;
          final ry = height / 2 - tile / 2 - 4;
          final placed = _evenlySpaced(rx, ry, n);
          points = placed.points;
          tile = (placed.step * 0.86).clamp(30.0, 84.0);
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
                // Dentro del círculo: la temática y, debajo, la bomba.
                Center(
                  child: SizedBox(
                    width: (rx - tile / 2) * 2 * 0.86,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title case final title?) ...[
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppFonts.display,
                              fontSize: (min(rx, ry) * 0.17).clamp(18.0, 30.0),
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              shadows: const [
                                Shadow(color: Colors.black38, blurRadius: 6),
                              ],
                            ),
                          ),
                          SizedBox(height: min(rx, ry) * 0.08),
                        ],
                        _bomb(title == null ? min(rx, ry) : min(rx, ry) * 0.75),
                      ],
                    ),
                  ),
                ),
                for (var i = 0; i < letters.length; i++)
                  Positioned(
                    left: width / 2 + points[i].dx - tile / 2,
                    top: height / 2 + points[i].dy - tile / 2,
                    // Cada letra mira hacia afuera: derecha para quien esté
                    // sentado frente a ella (se juega con el celular en el
                    // centro y la gente alrededor).
                    child: Transform.rotate(
                      angle: atan2(points[i].dy, points[i].dx) - pi / 2,
                      child: _LetterTile(
                        letter: letters[i],
                        size: tile,
                        used: used.contains(letters[i]),
                        onTap: enabled && !used.contains(letters[i])
                            ? () => onTap(letters[i])
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// La bomba (late con cada tic) y, en el modo de 11 segundos, los que
  /// quedan encima. [radius] es el tamaño de referencia.
  Widget _bomb(double radius) {
    return AnimatedScale(
      scale: pulse ? 1.12 : 1,
      duration: const Duration(milliseconds: 90),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text('💣', style: TextStyle(fontSize: radius * 0.7)),
          if (seconds case final seconds?)
            Padding(
              // Sobre el cuerpo de la bomba, no sobre la mecha.
              padding: EdgeInsets.only(top: radius * 0.18, right: radius * 0.1),
              child: Text(
                '$seconds',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: radius * 0.42,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: seconds <= 3 ? AppColors.yellow : Colors.white,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ),
        ],
      ),
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

/// Un botón redondo de los que se espichan: una tapa blanca sobre su base.
/// Al tocarlo baja, y si la letra ya se usó se queda abajo (espichado).
class _LetterTile extends StatefulWidget {
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
  State<_LetterTile> createState() => _LetterTileState();
}

class _LetterTileState extends State<_LetterTile> {
  /// El dedo está encima del botón.
  bool _down = false;

  void _press(bool down) {
    if (widget.onTap == null || _down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final used = widget.used;
    final pressed = used || _down;
    // Lo que sobresale la tapa sobre la base.
    final depth = size * 0.12;
    final face = size - depth;
    final lift = pressed ? depth * 0.15 : depth;
    return Semantics(
      button: !used,
      label: used ? '${widget.letter}, usada' : 'Letra ${widget.letter}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onTap,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            children: [
              // La base del botón, oscura, con su sombra en el piso.
              Positioned(
                left: depth / 2,
                top: depth,
                child: Container(
                  width: face,
                  height: face,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: used ? const Color(0xFF5B3E8C) : AppColors.ink,
                    boxShadow: [
                      if (!used)
                        const BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                    ],
                  ),
                ),
              ),
              // La tapa: sube y baja.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 70),
                curve: Curves.easeOut,
                left: depth / 2,
                top: depth - lift,
                child: Container(
                  width: face,
                  height: face,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: used ? const Color(0xFF5B3E8C) : AppColors.ink,
                      width: max(2, size * 0.04),
                    ),
                    // Arriba más clara si está afuera; hundida, más oscura
                    // arriba, como si le diera la sombra del borde.
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: used
                          ? const [Color(0xFFB8AECB), Color(0xFFD9D3E4)]
                          : pressed
                          ? const [Color(0xFFDCD6E8), Color(0xFFF4F1FA)]
                          : const [Colors.white, Color(0xFFE3DDEE)],
                    ),
                  ),
                  child: Text(
                    widget.letter,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: face * 0.55,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: used
                          ? AppColors.ink.withValues(alpha: 0.4)
                          : AppColors.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
