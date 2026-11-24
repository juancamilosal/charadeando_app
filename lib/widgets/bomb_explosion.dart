import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// ¡BOOM! La explosión de la bomba de Letras: un destello blanco, una bola
/// de fuego que crece, chispas que salen volando, humo y la pantalla que
/// tiembla, con "¡BOOM!" en el centro. Dura [duration] y queda en el
/// último cuadro (humo y el texto).
class BombExplosion extends StatefulWidget {
  const BombExplosion({
    super.key,
    this.duration = const Duration(milliseconds: 1800),
    this.progress,
  });

  final Duration duration;

  /// Para las capturas y las pruebas: muestra la explosión fija en este
  /// punto (0 a 1) en vez de animarla.
  final double? progress;

  @override
  State<BombExplosion> createState() => _BombExplosionState();
}

class _BombExplosionState extends State<BombExplosion>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.progress == null) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = widget.progress ?? _controller.value;
        // La pantalla tiembla al principio y se va calmando.
        final shake = (1 - t).clamp(0.0, 1.0) * 14;
        final dx = sin(t * 90) * shake;
        final dy = cos(t * 77) * shake;
        return Transform.translate(
          offset: Offset(dx, dy),
          child: CustomPaint(
            painter: _ExplosionPainter(t),
            child: Center(child: _BoomText(t: t)),
          ),
        );
      },
    );
  }
}

class _BoomText extends StatelessWidget {
  const _BoomText({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    // Aparece de golpe, rebota y se queda.
    final appear = Curves.elasticOut.transform((t / 0.55).clamp(0.0, 1.0));
    return Transform.rotate(
      angle: -0.08,
      child: Transform.scale(
        scale: 0.2 + appear * 0.8,
        child: Opacity(
          opacity: (t / 0.1).clamp(0.0, 1.0),
          child: Text(
            '¡BOOM!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 110,
              fontWeight: FontWeight.w700,
              color: AppColors.yellow,
              height: 1,
              shadows: const [
                Shadow(color: AppColors.red, offset: Offset(6, 6)),
                Shadow(color: Colors.black54, blurRadius: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplosionPainter extends CustomPainter {
  _ExplosionPainter(this.t);

  final double t;

  // Siempre las mismas chispas, para que la animación no salte.
  static final _sparks = () {
    final random = Random(42);
    return [
      for (var i = 0; i < 48; i++)
        (
          angle: random.nextDouble() * 2 * pi,
          speed: 0.45 + random.nextDouble() * 0.75,
          size: 4.0 + random.nextDouble() * 10,
          hot: random.nextBool(),
        ),
    ];
  }();

  static final _puffs = () {
    final random = Random(7);
    return [
      for (var i = 0; i < 14; i++)
        (
          angle: random.nextDouble() * 2 * pi,
          distance: 0.15 + random.nextDouble() * 0.35,
          size: 0.18 + random.nextDouble() * 0.2,
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final reach = size.longestSide * 0.75;

    // Fondo oscuro, como si se fuera la luz. Más grande que la pantalla,
    // para que al temblar no se vea el borde.
    canvas.drawRect(
      (Offset.zero & size).inflate(40),
      Paint()..color = const Color(0xFF1A0B0B).withValues(alpha: 0.85),
    );

    // Humo gris que se queda.
    final smoke = (t * 1.4).clamp(0.0, 1.0);
    for (final p in _puffs) {
      final offset =
          center +
          Offset(cos(p.angle), sin(p.angle)) * reach * p.distance * smoke;
      canvas.drawCircle(
        offset,
        reach * p.size * (0.4 + smoke * 0.6),
        Paint()
          ..color = const Color(0xFF5A5050).withValues(alpha: 0.35 * smoke)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
    }

    // Bola de fuego: crece rápido y se va apagando.
    final grow = Curves.easeOutCubic.transform((t / 0.5).clamp(0.0, 1.0));
    final fade = (1 - ((t - 0.35) / 0.65)).clamp(0.0, 1.0);
    if (fade > 0) {
      final radius = reach * 0.55 * grow;
      canvas.drawCircle(
        center,
        max(radius, 1),
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: fade),
                  AppColors.yellow.withValues(alpha: fade),
                  AppColors.orange.withValues(alpha: fade),
                  AppColors.red.withValues(alpha: 0.8 * fade),
                  AppColors.red.withValues(alpha: 0),
                ],
                stops: const [0, 0.2, 0.45, 0.75, 1],
              ).createShader(
                Rect.fromCircle(center: center, radius: max(radius, 1)),
              ),
      );
    }

    // Chispas que salen volando y caen.
    for (final s in _sparks) {
      final travel = Curves.easeOut.transform(t) * s.speed * reach * 0.8;
      final fall = t * t * reach * 0.25;
      final offset =
          center + Offset(cos(s.angle) * travel, sin(s.angle) * travel + fall);
      final life = (1 - t * 0.9).clamp(0.0, 1.0);
      canvas.drawCircle(
        offset,
        s.size * life,
        Paint()
          ..color = (s.hot ? AppColors.yellow : AppColors.orange).withValues(
            alpha: life,
          ),
      );
    }

    // Destello blanco del primer instante.
    final flash = (1 - t / 0.18).clamp(0.0, 1.0);
    if (flash > 0) {
      canvas.drawRect(
        (Offset.zero & size).inflate(40),
        Paint()..color = Colors.white.withValues(alpha: flash),
      );
    }
  }

  @override
  bool shouldRepaint(_ExplosionPainter old) => old.t != t;
}
