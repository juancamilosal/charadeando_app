import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';

import '../services/services.dart';
import '../providers/providers.dart';
import '../theme.dart';

enum _Spin { idle, spinning, stopping, result }

/// Cómo arrancó un giro: desde qué ángulo y, si fue con el dedo, a qué
/// velocidad (radianes por segundo; positiva en el sentido del reloj).
/// Sirve para seguir el mismo giro en otra pantalla.
class RouletteSpin {
  const RouletteSpin({required this.angle, this.omega});

  final double angle;

  /// Null si se giró con el botón "Girar".
  final double? omega;
}

/// Ruleta de castigos con su botón. "Girar" la pone a toda velocidad hasta
/// que tocan "¡Parar!" (o pasan 30 segundos); entonces se elige el castigo
/// al azar y la ruleta frena poco a poco hasta el centro de ese campo.
/// También se puede girar con el dedo: sigue al dedo y, si se suelta con
/// impulso, gira hacia ese lado y frena sola.
class PunishmentRoulette extends ConsumerStatefulWidget {
  const PunishmentRoulette({
    super.key,
    required this.punishments,
    required this.onDone,
    this.onSkip,
    this.autoStart = false,
    this.random,
    this.onBeforeSpin,
    this.onResult,
    this.startWith,
    this.dragToSpin = true,
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

  /// Se llama antes de girar; si devuelve falso, no gira (por ejemplo,
  /// porque faltan castigos).
  final bool Function(RouletteSpin spin)? onBeforeSpin;

  /// Un giro que empezó en otra pantalla: la ruleta arranca en ese ángulo y,
  /// con [autoStart], gira igual (con el dedo, hacia el mismo lado).
  final RouletteSpin? startWith;

  /// Avisa si se está mostrando el castigo que salió (verdadero) o la
  /// ruleta vuelve a girar (falso).
  final ValueChanged<bool>? onResult;

  /// Si se gira con el dedo. Dentro de una pantalla que se desplaza (la
  /// sección Ruleta y el final de la partida) no: deslizar el dedo encima
  /// baja la pantalla, y se gira con "Girar" o tocando la ruleta.
  final bool dragToSpin;

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
  ConsumerState<PunishmentRoulette> createState() => _PunishmentRouletteState();
}

class _PunishmentRouletteState extends ConsumerState<PunishmentRoulette>
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

  /// Lo que tarda en frenar: 10 segundos con "¡Parar!"; al soltarla con el
  /// dedo, según la fuerza.
  double _stopSeconds = PunishmentRoulette.stopDuration.inMilliseconds / 1000;

  /// Al arrastrarla: la última posición del dedo.
  Offset? _fingerPos;
  Offset _center = Offset.zero;
  int _chosen = 0;
  int _lastField = 0;

  int get _fields => widget.punishments.length;

  @override
  void initState() {
    super.initState();
    final start = widget.startWith;
    if (start != null) _angle = start.angle;
    _lastField = Roulette.fieldAt(_angle, _fields);
    if (widget.autoStart) {
      final omega = start?.omega;
      omega == null ? _start() : _fling(omega);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _start() {
    if (widget.onBeforeSpin?.call(RouletteSpin(angle: _angle)) == false) {
      return;
    }
    if (_spin == _Spin.result) widget.onResult?.call(false);
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
    _stopSeconds = seconds;
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
        final t = seconds / _stopSeconds;
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
      // Un clic por cada castigo que pasa: así el sonido va al ritmo de la
      // ruleta y se espacia solo cuando frena.
      ref.read(hapticsProvider).selection();
      ref.read(soundServiceProvider).play(SoundEffect.spin);
    }
    setState(() => _angle = angle);
  }

  void _land() {
    _ticker.stop();
    final haptics = ref.read(hapticsProvider);
    haptics.heavy();
    haptics.vibrate();
    setState(() {
      _angle = _to;
      _spin = _Spin.result;
    });
    _reveal.forward();
    widget.onResult?.call(true);
  }

  /// Velocidad mínima (radianes por segundo) para que al soltarla gire.
  static const _minFling = 2.5;

  bool get _canDrag => _spin == _Spin.idle || _spin == _Spin.result;

  void _dragStart(DragStartDetails d) {
    if (!_canDrag) return;
    _fingerPos = d.localPosition;
  }

  /// Cuánto gira la ruleta (en radianes, positivo en el sentido del reloj)
  /// cuando el dedo, puesto en [at], se mueve [move]. Gira hacia donde se
  /// mueve el dedo: a la derecha, en el sentido del reloj; a la izquierda,
  /// al revés. Si el dedo va más que todo hacia arriba o hacia abajo, gira
  /// como si lo arrastrara por ese lado de la ruleta.
  double _turn(Offset at, Offset move) {
    final radius = max(_center.dx, 20.0);
    if (move.dx.abs() >= move.dy.abs()) return move.dx / radius;
    final side = at.dx >= _center.dx ? 1.0 : -1.0;
    return side * move.dy / radius;
  }

  /// La ruleta sigue al dedo.
  void _dragUpdate(DragUpdateDetails d) {
    final last = _fingerPos;
    if (last == null || !_canDrag) return;
    _fingerPos = d.localPosition;
    _setAngle(_angle + _turn(last, d.delta));
  }

  /// Al soltarla con impulso, gira hacia ese lado y frena sola. El castigo
  /// igual sale al azar: la fuerza solo cambia cuánto tarda.
  void _dragEnd(DragEndDetails d) {
    final pos = _fingerPos;
    _fingerPos = null;
    if (pos == null || !_canDrag) return;
    final omega = _turn(pos, d.velocity.pixelsPerSecond);
    if (omega.abs() < _minFling) return;
    _fling(omega.clamp(-25.0, 25.0));
  }

  void _fling(double omega) {
    final spin = RouletteSpin(angle: _angle, omega: omega);
    if (widget.onBeforeSpin?.call(spin) == false) return;
    if (_spin == _Spin.result) widget.onResult?.call(false);
    _ticker.stop();
    _reveal.reset();
    _chosen = Roulette.pickField(_fields, _random);
    final speed = omega.abs();
    // Más fuerza, más vueltas: entre 3 y 9 segundos frenando.
    final seconds = (speed / 2).clamp(3.0, 9.0);
    _to = Roulette.stopAngle(
      from: _angle,
      field: _chosen,
      fields: _fields,
      minDistance: speed * seconds / 4,
      direction: omega.sign.toInt(),
    );
    // Con easeOutQuart la velocidad inicial es 4 · distancia / duración.
    _stopSeconds = max(1.5, 4 * (_to - _angle).abs() / speed);
    setState(() {
      _spin = _Spin.stopping;
      _from = _angle;
    });
    _ticker.start();
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
              // Se puede girar con el dedo, hacia un lado o hacia el otro.
              child: LayoutBuilder(
                builder: (context, box) {
                  _center = Offset(box.maxWidth / 2, box.maxHeight / 2);
                  final face = CustomPaint(
                    size: Size.infinite,
                    painter: RoulettePainter(
                      punishments: widget.punishments,
                      angle: _angle,
                    ),
                  );
                  if (!widget.dragToSpin) {
                    // Tocarla es como tocar "Girar"; los arrastres son de
                    // la pantalla.
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _spin == _Spin.idle ? _start : null,
                      child: face,
                    );
                  }
                  // Toma el dedo apenas toca la ruleta, por cualquier
                  // lado: si no, la pantalla se quedaba con los arrastres
                  // hacia arriba o abajo y solo giraba tomándola de arriba.
                  return RawGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    gestures: {
                      _EagerPan:
                          GestureRecognizerFactoryWithHandlers<_EagerPan>(
                            _EagerPan.new,
                            (pan) => pan
                              ..onStart = _dragStart
                              ..onUpdate = _dragUpdate
                              ..onEnd = _dragEnd,
                          ),
                    },
                    child: face,
                  );
                },
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
///
/// La cara de la ruleta (campos y textos) se dibuja una sola vez y luego
/// solo se gira: así los textos quedan pegados a la ruleta mientras da
/// vueltas, y no se vuelven a acomodar en cada cuadro.
class RoulettePainter extends CustomPainter {
  RoulettePainter({required this.punishments, required this.angle});

  final List<String> punishments;

  /// Giro de la ruleta en radianes, en el sentido del reloj.
  final double angle;

  /// Caras ya dibujadas, por castigos y tamaño.
  static final _faces = <int, ui.Picture>{};

  @override
  void paint(Canvas canvas, Size size) {
    final pointerHeight = size.width * 0.08;
    final radius = size.width / 2 - pointerHeight * 0.55;
    final center = Offset(
      size.width / 2,
      size.height / 2 + pointerHeight * 0.3,
    );

    canvas.drawCircle(
      center.translate(0, 4),
      radius + 6,
      Paint()
        ..color = Colors.black26
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(center, radius + 6, Paint()..color = Colors.white);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawPicture(_face(radius));
    canvas.restore();

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

  /// Campos y textos sin girar, con el centro en (0, 0).
  ui.Picture _face(double radius) {
    final key = Object.hash(Object.hashAll(punishments), radius.round());
    final cached = _faces[key];
    if (cached != null) return cached;
    if (_faces.length > 8) _faces.clear();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final fields = punishments.length;
    final seg = Roulette.segment(fields);
    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
    for (var i = 0; i < fields; i++) {
      final color = PunishmentRoulette.colors[i % 10];
      final start = -pi / 2 + i * seg;
      canvas.drawArc(rect, start, seg, true, Paint()..color = color);
      canvas.drawLine(
        Offset.zero,
        Offset(cos(start), sin(start)) * radius,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2,
      );
      if (punishments[i].isNotEmpty) {
        _paintLabel(canvas, radius, start + seg / 2, seg, i, color);
      }
    }
    return _faces[key] = recorder.endRecording();
  }

  void _paintLabel(
    Canvas canvas,
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
    // Los textos de la mitad izquierda (con la ruleta quieta) se giran
    // media vuelta para que no queden de cabeza. Se decide una sola vez,
    // así que al girar el texto no cambia de lado.
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

/// Arrastre que gana apenas el dedo toca, para que la lista de la pantalla
/// no se quede con él.
class _EagerPan extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
