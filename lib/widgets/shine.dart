import 'package:flutter/material.dart';

/// Un brillo que cruza en diagonal, como cuando brilla el oro, y después
/// espera. Va encima de una tarjeta (no recibe toques). [offset] (de 0 a 1)
/// corre el momento del brillo, para que varias tarjetas no brillen a la
/// vez. Si el celular pide menos animaciones, no se mueve.
class Shine extends StatefulWidget {
  const Shine({super.key, this.offset = 0});

  /// Cada cuánto pasa el brillo.
  static const period = Duration(seconds: 6);

  /// Parte de [period] que dura el brillo cruzando.
  static const sweep = 0.16;

  final double offset;

  @override
  State<Shine> createState() => _ShineState();
}

class _ShineState extends State<Shine> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Shine.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller
        ..value = widget.offset % 1
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value / Shine.sweep;
          if (t >= 1) return const SizedBox.expand();
          return CustomPaint(size: Size.infinite, painter: _ShinePainter(t));
        },
      ),
    );
  }
}

class _ShinePainter extends CustomPainter {
  _ShinePainter(this.t);

  /// De 0 (antes de entrar por la izquierda) a 1 (ya salió por la derecha).
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final band = size.width * 0.45;
    // Inclinada, la franja ocupa media altura de más a cada lado: entra
    // justo por la izquierda y sale justo por la derecha.
    final lean = size.height * 0.3;
    final start = -band - lean;
    final travel = size.width + band + lean * 2;
    final x = start + travel * Curves.easeInOut.transform(t);
    final rect = Rect.fromLTWH(x, 0, band, size.height);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x00FFFFFF), Color(0x66FFFFFF), Color(0x00FFFFFF)],
        stops: [0, 0.5, 1],
      ).createShader(rect);
    canvas
      ..save()
      ..translate(x + band / 2, size.height / 2)
      ..skew(-0.6, 0)
      ..translate(-(x + band / 2), -size.height / 2)
      ..drawRect(rect.inflate(size.height), paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_ShinePainter old) => old.t != t;
}
