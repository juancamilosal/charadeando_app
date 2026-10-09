import 'package:sensors_plus/sensors_plus.dart';

/// Acción detectada al inclinar el celular que está en la frente.
enum TiltAction { hit, pass }

/// Convierte lecturas del eje Z del acelerómetro en aciertos y pases.
///
/// Con el celular vertical en la frente, Z vale cerca de 0. Al inclinar la
/// pantalla hacia el piso Z baja (acierto) y hacia el techo sube (pasar).
/// La primera lectura fija la posición neutra del jugador, y después de cada
/// acción hay que volver a ella antes de que cuente la siguiente; así una
/// sola inclinación no se cuenta dos veces.
class TiltDetector {
  TiltDetector({
    this.triggerThreshold = 6.0,
    this.neutralThreshold = 3.0,
    this.maxBaseline = 4.0,
    this.smoothing = 0.35,
  });

  /// Diferencia con la posición neutra (m/s²) que dispara una acción.
  /// 6 m/s² equivale a unos 40° de inclinación.
  final double triggerThreshold;

  /// Diferencia máxima para considerar que el celular volvió a la neutra.
  final double neutralThreshold;

  /// Límite de la posición neutra, por si se calibra con el celular inclinado.
  final double maxBaseline;

  /// Peso de cada lectura nueva en el filtro que suaviza el temblor.
  final double smoothing;

  double? _filtered;
  double? _baseline;
  bool _armed = false;

  /// Olvida la calibración; la siguiente lectura fija la posición neutra.
  void reset() {
    _filtered = null;
    _baseline = null;
    _armed = false;
  }

  TiltAction? addSample(double z) {
    final previous = _filtered;
    final filtered = previous == null
        ? z
        : previous + smoothing * (z - previous);
    _filtered = filtered;

    final baseline = _baseline ??= filtered
        .clamp(-maxBaseline, maxBaseline)
        .toDouble();
    final delta = filtered - baseline;

    if (!_armed) {
      if (delta.abs() < neutralThreshold) _armed = true;
      return null;
    }
    if (delta <= -triggerThreshold) {
      _armed = false;
      return TiltAction.hit;
    }
    if (delta >= triggerThreshold) {
      _armed = false;
      return TiltAction.pass;
    }
    return null;
  }
}

class TiltService {
  /// Emite una acción cada vez que el jugador inclina el celular. Cada
  /// suscripción calibra su propia posición neutra.
  Stream<TiltAction> actions() {
    final detector = TiltDetector();
    return accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
        .map((event) => detector.addSample(event.z))
        .where((action) => action != null)
        .cast<TiltAction>();
  }
}
