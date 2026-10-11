import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../services/punishments.dart';
import '../theme.dart';

enum _Spin { idle, spinning, stopping, result }

/// Ruleta de castigos con su botón. "Girar" la pone a toda velocidad hasta
/// que tocan "¡Parar!" (o pasan 30 segundos); entonces se elige el castigo
/// al azar y la ruleta frena poco a poco hasta el centro de ese campo.
class PunishmentRoulette extends StatefulWidget {
  const PunishmentRoulette({
    super.key,
    required this.punishments,
    required this.onDone,
    this.onSkip,
    this.autoStart = false,
    this.random,
  });

  /// Un castigo por campo, en el sentido del reloj desde arriba.
  final List<String> punishments;

  /// Botón "Listo" después de caer en un castigo.
  final VoidCallback onDone;

  /// Botón "Sin castigo" antes de girar, si se puede saltar.
  final VoidCallback? onSkip;

  /// Empieza a girar apenas aparece.
  final bool autoStart;
  final Random? random;

  /// Vueltas por segundo a toda velocidad.
  static const turnsPerSecond = 2.0;

  /// Cuánto tarda en frenar.
  static const stopDuration = Duration(seconds: 10);

  /// Si nadie toca "¡Parar!", la ruleta frena sola después de este tiempo.
  static const autoStopAfter = Duration(seconds: 30);

  static const colors = [
    AppColors.purple,
    AppColors.yellow,
    AppColors.turquoise,
    AppColors.coral,
    AppColors.blue,
    AppColors.green,
    AppColors.magenta,
    AppColors.orange,
    AppColors.indigo,
    AppColors.pink,
  ];

  @override
  State<PunishmentRoulette> createState() => _PunishmentRouletteState();
}

class _PunishmentRouletteState extends State<PunishmentRoulette>
    with TickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  late final Random _random = widget.random ?? Random();
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  static const _speed = PunishmentRoulette.turnsPerSecond * 2 * pi;

  _Spin _spin = _Spin.idle;
  double _angle = 0;

  /// Ángulo al empezar la fase actual (girar o frenar).
  double _from = 0;
  double _to = 0;
  int _chosen = 0;
  int _lastField = 0;

  int get _fields => widget.punishments.length;

  @override
  void initState() {
    super.initState();
    _lastField = Roulette.fieldAt(_angle, _fields);
    if (widget.autoStart) _start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _start() {
    _ticker.stop();
    _reveal.reset();
    setState(() {
      _spin = _Spin.spinning;
      _from = _angle;
    });
    _ticker.start();
  }

  void _stop() {
    if (_spin != _Spin.spinning) return;
    _ticker.stop();
    // El castigo se elige al azar: el momento del toque no influye.
    _chosen = Roulette.pickField(_fields, _random);
    final seconds = PunishmentRoulette.stopDuration.inMilliseconds / 1000;
    // Con easeOutQuart la velocidad inicial es 4 · distancia / duración:
    // así arranca a la misma velocidad que traía.
    _to = Roulette.stopAngle(
      from: _angle,
      field: _chosen,
      fields: _fields,
      minDistance: _speed * seconds / 4,
    );
    setState(() {
      _spin = _Spin.stopping;
      _from = _angle;
    });
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final seconds = elapsed.inMicroseconds / 1e6;
    switch (_spin) {
      case _Spin.spinning:
        _setAngle(_from + _speed * seconds);
        if (elapsed >= PunishmentRoulette.autoStopAfter) _stop();
      case _Spin.stopping:
        final total = PunishmentRoulette.stopDuration.inMicroseconds / 1e6;
        final t = seconds / total;
        _setAngle(_from + (_to - _from) * Roulette.easeOutQuart(t));
        if (t >= 1) _land();
      case _Spin.idle:
      case _Spin.result:
        break;
    }
  }

  void _setAngle(double angle) {
    final field = Roulette.fieldAt(angle, _fields);
    if (field != _lastField) {
      _lastField = field;
      HapticFeedback.selectionClick();
    }
    setState(() => _angle = angle);
  }

  void _land() {
    _ticker.stop();
    HapticFeedback.heavyImpact();
    HapticFeedback.vibrate();
    setState(() {
      _angle = _to;
      _spin = _Spin.result;
    });
    _reveal.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: RoulettePainter(
                  punishments: widget.punishments,
                  angle: _angle,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_spin == _Spin.result) _result() else _spinButton(),
      ],
    );
  }

  Widget _spinButton() {
    final spinning = _spin == _Spin.spinning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          icon: Icon(switch (_spin) {
            _Spin.spinning => Icons.pan_tool,
            _Spin.stopping => Icons.hourglass_bottom,
            _ => Icons.autorenew,
          }),
          label: Text(switch (_spin) {
            _Spin.spinning => '¡Parar!',
            _Spin.stopping => 'Frenando…',
            _ => 'Girar',
          }),
          style: spinning
              ? FilledButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: switch (_spin) {
            _Spin.idle => _start,
            _Spin.spinning => _stop,
            _ => null,
          },
        ),
        if (_spin == _Spin.idle && widget.onSkip != null) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: widget.onSkip,
            child: const Text('Sin castigo'),
          ),
        ],
      ],
    );
  }

  Widget _result() {
    final color = PunishmentRoulette.colors[_chosen % 10];
    final onColor = color == AppColors.yellow ? AppColors.ink : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScaleTransition(
          scale: CurvedAnimation(parent: _reveal, curve: Curves.elasticOut),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 14),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '¡Castigo!',
                  style: TextStyle(
                    color: onColor.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  widget.punishments[_chosen],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 28,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: onColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.autorenew),
                label: const Text('Girar otra vez', maxLines: 1),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: _start,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Listo'),
                onPressed: widget.onDone,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dibujo de la ruleta: los campos de colores con su castigo, el centro
/// redondo y el indicador fijo arriba.
class RoulettePainter extends CustomPainter {
  RoulettePainter({required this.punishments, required this.angle});

  final List<String> punishments;

  /// Giro de la ruleta en radianes, en el sentido del reloj.
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final fields = punishments.length;
    final seg = Roulette.segment(fields);
    final pointerHeight = size.width * 0.08;
    final radius = size.width / 2 - pointerHeight * 0.55;
    final center = Offset(
      size.width / 2,
      size.height / 2 + pointerHeight * 0.3,
    );
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center.translate(0, 4),
      radius + 6,
      Paint()
        ..color = Colors.black26
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(center, radius + 6, Paint()..color = Colors.white);

    for (var i = 0; i < fields; i++) {
      final color = PunishmentRoulette.colors[i % 10];
      final start = -pi / 2 + angle + i * seg;
      canvas.drawArc(rect, start, seg, true, Paint()..color = color);
      canvas.drawLine(
        center,
        center + Offset(cos(start), sin(start)) * radius,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2,
      );
      _paintLabel(canvas, center, radius, start + seg / 2, seg, i, color);
    }

    // Centro redondo.
    canvas.drawCircle(center, radius * 0.17, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      radius * 0.17,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(center, radius * 0.07, Paint()..color = AppColors.purple);

    // Indicador fijo arriba, apuntando hacia la ruleta.
    final top = center.dy - radius - 6;
    final half = pointerHeight * 0.6;
    final pointer = Path()
      ..moveTo(center.dx - half, top - pointerHeight * 0.45)
      ..lineTo(center.dx + half, top - pointerHeight * 0.45)
      ..lineTo(center.dx, top + pointerHeight * 0.75)
      ..close();
    canvas.drawPath(
      pointer.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black26
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(pointer, Paint()..color = AppColors.yellow);
    canvas.drawPath(
      pointer,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintLabel(
    Canvas canvas,
    Offset center,
    double radius,
    double direction,
    double seg,
    int index,
    Color color,
  ) {
    final inner = radius * 0.22;
    // Deja libre la punta del indicador, que entra un poco en la ruleta.
    final outer = radius * 0.85;
    final fontSize = radius * (punishments.length > 6 ? 0.075 : 0.09);
    final left = cos(direction) < -1e-6;
    final painter = TextPainter(
      text: TextSpan(
        text: punishments[index],
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: fontSize,
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: color == AppColors.yellow ? AppColors.ink : Colors.white,
        ),
      ),
      textAlign: left ? TextAlign.start : TextAlign.end,
      textDirection: TextDirection.ltr,
      // Con dos campos cada uno es media ruleta: caben tres renglones.
      maxLines: punishments.length > 2 ? 2 : 3,
      ellipsis: '…',
    )..layout(maxWidth: outer - inner);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Los textos de la mitad izquierda se giran media vuelta para que no
    // queden de cabeza; se leen desde el borde hacia el centro.
    if (left) {
      canvas.rotate(direction + pi);
      painter.paint(canvas, Offset(-outer, -painter.height / 2));
    } else {
      canvas.rotate(direction);
      painter.paint(canvas, Offset(outer - painter.width, -painter.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RoulettePainter old) =>
      old.angle != angle || old.punishments != punishments;
}
