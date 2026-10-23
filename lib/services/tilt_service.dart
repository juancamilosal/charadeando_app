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
/// inclinación tiene que sostenerse un momento: los golpes y sacudidas
/// sueltos no cuentan.
///
/// El filtro y la espera se miden en tiempo, no en lecturas: hay celulares
/// que entregan las lecturas más espaciadas, y contadas por lecturas el
/// acierto tardaba más en llegar.
class TiltDetector {
  TiltDetector({
    this.triggerAngle = 28,
    this.neutralAngle = 15,
    this.maxBaseline = 50,
    this.limitAngle = 75,
    this.holdTime = const Duration(milliseconds: 60),
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

  /// Cuánto tiene que durar la inclinación para contar.
  final Duration holdTime;

  /// Peso de una lectura nueva en el filtro que suaviza el temblor, para
  /// lecturas cada [sampleInterval]; con lecturas más espaciadas pesa más.
  final double smoothing;

  /// Qué tan rápido la neutra sigue al jugador cuando está quieto en ella,
  /// también por cada [sampleInterval].
  final double drift;

  /// Intervalo de referencia entre lecturas (el que pide la app) y el que
  /// se supone cuando una lectura no trae la hora.
  static const sampleInterval = Duration(milliseconds: 20);

  List<double>? _filtered;
  double? _baseline;

  /// La gravedad medida en la primera lectura, con el celular quieto.
  double _g = gravity;
  bool _armed = false;
  TiltAction? _pending;

  /// Tiempo que lleva sostenida la inclinación [_pending].
  Duration _held = Duration.zero;
  DateTime? _lastAt;

  /// Olvida la calibración; la siguiente lectura fija la posición neutra.
  void reset() {
    _filtered = null;
    _baseline = null;
    _g = gravity;
    _armed = false;
    _pending = null;
    _held = Duration.zero;
    _lastAt = null;
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

  /// Tiempo desde la lectura anterior. Sin hora (o con una hora rara) se
  /// supone el intervalo de referencia; una pausa larga cuenta como mucho
  /// 250 ms.
  Duration _elapsed(DateTime? at) {
    final last = _lastAt;
    _lastAt = at;
    if (at == null || last == null) return sampleInterval;
    final dt = at.difference(last);
    if (dt <= Duration.zero) return sampleInterval;
    const most = Duration(milliseconds: 250);
    return dt > most ? most : dt;
  }

  /// [weight] por [sampleInterval] llevado a una espera de [dt].
  static double _scaled(double weight, Duration dt) {
    if (weight >= 1) return 1;
    final steps = dt.inMicroseconds / sampleInterval.inMicroseconds;
    return 1 - pow(1 - weight, steps).toDouble();
  }

  /// Procesa una lectura. [at] es su hora (la del sensor); sin ella se
  /// supone una lectura cada [sampleInterval].
  TiltAction? addSample(double x, double y, double z, {DateTime? at}) {
    final dt = _elapsed(at);
    final previous = _filtered;
    final alpha = _scaled(smoothing, dt);
    final filtered = previous == null
        ? [x, y, z]
        : [
            for (final (i, v) in [x, y, z].indexed)
              previous[i] + alpha * (v - previous[i]),
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
      _baseline = baseline + _scaled(drift, dt) * delta;
    }
    final hitAt = max(baseline - triggerAngle, -limitAngle);
    final passAt = min(baseline + triggerAngle, limitAngle);
    final action = angle <= hitAt
        ? TiltAction.hit
        : angle >= passAt
        ? TiltAction.pass
        : null;
    // La primera lectura inclinada empieza a contar; las siguientes suman
    // el tiempo desde la anterior.
    if (action == null || action != _pending) {
      _pending = action;
      _held = Duration.zero;
    } else {
      _held += dt;
    }
    if (action == null || _held < holdTime) return null;
    _armed = false;
    _pending = null;
    _held = Duration.zero;
    return action;
  }
}

/// Reconoce cuándo el jugador ya tiene el celular en la frente: de lado,
/// con la pantalla casi vertical (como mucho [maxAngle] hacia el techo o el
/// piso) y quieto durante [still]. Así la inclinación se calibra con el
/// celular ya puesto, y no mientras lo acomodan. Quien lee la pantalla en
/// la mano suele tenerla inclinada hacia el techo, más que [maxAngle], y no
/// cuenta; con el celular debajo de la cara tampoco, y para eso la pantalla
/// ofrece "Empezar igual".
class ForeheadDetector {
  ForeheadDetector({
    this.maxAngle = 25,
    this.wobble = 8,
    this.still = const Duration(seconds: 1),
  });

  /// Inclinación máxima de la pantalla, en grados, para contar como puesta
  /// en la frente.
  final double maxAngle;

  /// Cuánto puede moverse el ángulo, en grados, y seguir contando como
  /// quieto.
  final double wobble;

  /// Cuánto tiempo tiene que estar quieto en la frente.
  final Duration still;

  DateTime? _lastAt;
  double? _anchor;
  Duration _held = Duration.zero;

  /// Procesa una lectura y responde si ya está en la frente. [at] es la
  /// hora del sensor; sin ella se supone una lectura cada 20 ms.
  bool addSample(double x, double y, double z, {DateTime? at}) {
    final last = _lastAt;
    _lastAt = at;
    var dt = TiltDetector.sampleInterval;
    if (at != null && last != null) {
      final d = at.difference(last);
      if (d > Duration.zero) {
        dt = d > const Duration(milliseconds: 250)
            ? const Duration(milliseconds: 250)
            : d;
      }
    }
    final magnitude = sqrt(x * x + y * y + z * z);
    final angle = TiltDetector.pitch(x, y, z);
    // Acostado en la mesa, sacudiéndolo o con la pantalla al techo no
    // cuenta.
    final upright =
        angle.abs() <= maxAngle &&
        (magnitude - TiltDetector.gravity).abs() < 2.5;
    final anchor = _anchor;
    if (!upright) {
      _anchor = null;
      _held = Duration.zero;
      return false;
    }
    if (anchor == null || (angle - anchor).abs() > wobble) {
      _anchor = angle;
      _held = Duration.zero;
      return false;
    }
    _held += dt;
    return _held >= still;
  }
}

class TiltService {
  /// Emite una acción cada vez que el jugador inclina el celular. Cada
  /// suscripción calibra su propia posición neutra.
  /// Termina (con un evento) cuando el jugador ya tiene el celular en la
  /// frente y quieto. Si el celular no tiene acelerómetro, el error llega
  /// por el stream.
  Stream<void> onForehead() {
    final detector = ForeheadDetector();
    return accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
        .where(
          (event) => detector.addSample(
            event.x,
            event.y,
            event.z,
            at: event.timestamp,
          ),
        )
        .take(1)
        .map((_) {});
  }

  Stream<TiltAction> actions() {
    final detector = TiltDetector();
    return accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
        .map(
          (event) => detector.addSample(
            event.x,
            event.y,
            event.z,
            at: event.timestamp,
          ),
        )
        .where((action) => action != null)
        .cast<TiltAction>();
  }
}
