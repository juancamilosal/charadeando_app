import 'package:charadeando_app/services/tilt_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Alimenta el detector con [z] varias veces para que el filtro se asiente.
List<TiltAction> feed(TiltDetector detector, double z, {int times = 15}) =>
    [for (var i = 0; i < times; i++) detector.addSample(z)]
        .whereType<TiltAction>()
        .toList();

void main() {
  test('inclinar hacia abajo es acierto y hacia arriba es pasar', () {
    final detector = TiltDetector();
    expect(feed(detector, 0), isEmpty);
    expect(feed(detector, -9), [TiltAction.hit]);
    expect(feed(detector, 0), isEmpty);
    expect(feed(detector, 9), [TiltAction.pass]);
  });

  test('no cuenta dos veces sin volver a la posición neutra', () {
    final detector = TiltDetector();
    feed(detector, 0);
    expect(feed(detector, -9), [TiltAction.hit]);
    expect(feed(detector, -5), isEmpty);
    expect(feed(detector, -9), isEmpty);
  });

  test('ignora movimientos pequeños', () {
    final detector = TiltDetector();
    feed(detector, 0);
    expect(feed(detector, 3), isEmpty);
    expect(feed(detector, -3), isEmpty);
  });

  test('calibra con la posición inicial de la cabeza', () {
    final detector = TiltDetector();
    feed(detector, 3);
    // Desde 3, llegar a -1 son solo 4 m/s²: no alcanza.
    expect(feed(detector, -1), isEmpty);
    expect(feed(detector, -4), [TiltAction.hit]);
  });

  test('reset vuelve a calibrar', () {
    final detector = TiltDetector();
    feed(detector, -9);
    detector.reset();
    feed(detector, 0);
    expect(feed(detector, -9), [TiltAction.hit]);
  });
}
