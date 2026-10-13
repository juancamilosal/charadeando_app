import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// Acción detectada al inclinar el celular que está en la frente.
enum TiltAction { hit, pass }

/// Convierte lecturas del acelerómetro en aciertos y pases.
///
/// Mide el ángulo de la pantalla con el horizonte: con el celular vertical
/// en la frente vale cerca de 0°; al inclinar la pantalla hacia el piso
/// baja (acierto) y hacia el techo sube (pasar). El ángulo sale de dos
/// formas, con el eje Z (hacia afuera de la pantalla) y con lo que queda de
/// la gravedad en el plano de la pantalla, y se usa la menor: al girar la
/// cabeza a un lado el giro empuja el eje Z pero no le quita gravedad al
/// plano, así que no cuenta como inclinación.
///
/// La primera lectura fija la posición neutra del jugador, que puede estar
/// bastante inclinada (por ejemplo, con el celular debajo de la cara), y
/// se ajusta despacio mientras está quieto en ella. Después de cada acción
/// hay que volver a la neutra antes de que cuente la siguiente, y la
/// inclinación tiene que sostenerse unas lecturas: los golpes y sacudidas
/// sueltos no cuentan.
class TiltDetector {
  TiltDetector({
    this.triggerAngle = 32,
    this.neutralAngle = 15,
    this.maxBaseline = 50,
    this.limitAngle = 75,
    this.holdSamples = 4,
    this.smoothing = 0.3,
    this.drift = 0.01,
  });

  static const gravity = 9.81;

  /// Grados de inclinación desde la neutra que disparan una acción.
  final double triggerAngle;

  /// Grados desde la neutra para considerar que el celular volvió a ella.
  final double neutralAngle;

  /// Límite de la posición neutra, en grados.
  final double maxBaseline;

  /// Hasta dónde se le pide inclinar: si la neutra ya está muy inclinada,
  /// basta con llegar aquí, para que siempre se pueda pasar o acertar.
  final double limitAngle;

  /// Lecturas seguidas (unos 20 ms cada una) que tiene que durar la
  /// inclinación para contar.
  final int holdSamples;

  /// Peso de cada lectura nueva en el filtro que suaviza el temblor.
  final double smoothing;

  /// Qué tan rápido la neutra sigue al jugador cuando está quieto en ella.
  final double drift;

  List<double>? _filtered;
  double? _baseline;

  /// La gravedad medida en la primera lectura, con el celular quieto.
  double _g = gravity;
  bool _armed = false;
  TiltAction? _pending;
  int _held = 0;

  /// Olvida la calibración; la siguiente lectura fija la posición neutra.
  void reset() {
    _filtered = null;
    _baseline = null;
    _g = gravity;
    _armed = false;
    _pending = null;
    _held = 0;
  }

  /// Ángulo (en grados) de la pantalla con el horizonte: positivo hacia el
  /// techo, negativo hacia el piso.
  /// [g] es la gravedad que mide este celular (cada sensor se desvía un
  /// poco de 9,81).
  static double pitch(double x, double y, double z, {double g = gravity}) {
    final byZ = asin((z / g).clamp(-1.0, 1.0));
    final inPlane = sqrt(x * x + y * y);
    final byPlane = acos((inPlane / g).clamp(0.0, 1.0)) * z.sign;
    final angle = byZ.abs() < byPlane.abs() ? byZ : byPlane;
    return angle * 180 / pi;
  }

  TiltAction? addSample(double x, double y, double z) {
    final previous = _filtered;
    final filtered = previous == null
        ? [x, y, z]
        : [
            for (final (i, v) in [x, y, z].indexed)
              previous[i] + smoothing * (v - previous[i]),
          ];
    _filtered = filtered;
    if (previous == null) {
      final measured = sqrt(x * x + y * y + z * z);
      // Si arranca en plena sacudida, mejor la de siempre.
      _g = (measured - gravity).abs() < 1.5 ? measured : gravity;
    }
    final angle = pitch(filtered[0], filtered[1], filtered[2], g: _g);

    final baseline = _baseline ??= angle
        .clamp(-maxBaseline, maxBaseline)
        .toDouble();
    final delta = angle - baseline;

    if (!_armed) {
      if (delta.abs() < neutralAngle) _armed = true;
      return null;
    }
    if (delta.abs() < neutralAngle) {
      _baseline = baseline + drift * delta;
    }
    final hitAt = max(baseline - triggerAngle, -limitAngle);
    final passAt = min(baseline + triggerAngle, limitAngle);
    final action = angle <= hitAt
        ? TiltAction.hit
        : angle >= passAt
        ? TiltAction.pass
        : null;
    if (action == null || action != _pending) {
      _pending = action;
      _held = action == null ? 0 : 1;
    } else {
      _held++;
    }
    if (action == null || _held < holdSamples) return null;
    _armed = false;
    _pending = null;
    _held = 0;
    return action;
  }
}

class TiltService {
  /// Emite una acción cada vez que el jugador inclina el celular. Cada
  /// suscripción calibra su propia posición neutra.
  Stream<TiltAction> actions() {
    final detector = TiltDetector();
    return accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
        .map((event) => detector.addSample(event.x, event.y, event.z))
        .where((action) => action != null)
        .cast<TiltAction>();
  }
}
