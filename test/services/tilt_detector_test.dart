import 'dart:math';

import 'package:charadeando_app/services/tilt_service.dart';
import 'package:flutter_test/flutter_test.dart';

const g = TiltDetector.gravity;

/// Lectura del acelerómetro con el celular horizontal (de lado) y la
/// pantalla inclinada [degrees] hacia el techo (negativo: hacia el piso).
/// [push] es una aceleración extra sobre el eje Z, como la de girar la
/// cabeza, y [side] una a lo largo del celular.
(double, double, double) reading(
  double degrees, {
  double push = 0,
  double side = 0,
}) {
  final a = degrees * pi / 180;
  return (g * cos(a), side, g * sin(a) + push);
}

/// Alimenta el detector varias veces con la misma lectura para que el
/// filtro se asiente.
List<TiltAction> feed(
  TiltDetector detector,
  double degrees, {
  int times = 15,
  double push = 0,
  double side = 0,
}) {
  final (x, y, z) = reading(degrees, push: push, side: side);
  return [for (var i = 0; i < times; i++) detector.addSample(x, y, z)]
      .whereType<TiltAction>()
      .toList();
}

void main() {
  test('inclinar hacia abajo es acierto y hacia arriba es pasar', () {
    final detector = TiltDetector();
    expect(feed(detector, 0), isEmpty);
    expect(feed(detector, -60), [TiltAction.hit]);
    expect(feed(detector, 0), isEmpty);
    expect(feed(detector, 60), [TiltAction.pass]);
  });

  test('no cuenta dos veces sin volver a la posición neutra', () {
    final detector = TiltDetector();
    feed(detector, 0);
    expect(feed(detector, -60), [TiltAction.hit]);
    expect(feed(detector, -30), isEmpty);
    expect(feed(detector, -60), isEmpty);
  });

  test('ignora movimientos pequeños', () {
    final detector = TiltDetector();
    feed(detector, 0);
    expect(feed(detector, 20), isEmpty);
    expect(feed(detector, -20), isEmpty);
  });

  test('girar la cabeza a un lado no cuenta como acierto ni pase', () {
    final detector = TiltDetector();
    feed(detector, 0);
    // El giro empuja el eje Z hacia la cabeza (y a lo largo del celular),
    // pero la pantalla sigue vertical.
    expect(feed(detector, 0, push: -6), isEmpty);
    expect(feed(detector, 0, push: -6, side: 4), isEmpty);
    expect(feed(detector, 0, push: 6), isEmpty);
    // Después, inclinar de verdad sí cuenta.
    expect(feed(detector, 0), isEmpty);
    expect(feed(detector, -60), [TiltAction.hit]);
  });

  test('un golpe suelto no cuenta: la inclinación tiene que sostenerse', () {
    final detector = TiltDetector(smoothing: 1);
    feed(detector, 0);
    expect(feed(detector, -60, times: 2), isEmpty);
    expect(feed(detector, 0), isEmpty);
    expect(feed(detector, -60, times: 4), [TiltAction.hit]);
  });

  test('calibra con la posición inicial de la cabeza', () {
    final detector = TiltDetector();
    feed(detector, 20);
    // Desde 20°, llegar a -5° son solo 25°: no alcanza.
    expect(feed(detector, -5), isEmpty);
    expect(feed(detector, -20), [TiltAction.hit]);
  });

  test('con el celular debajo de la cara, inclinado hacia arriba, también '
      'se puede pasar', () {
    final detector = TiltDetector();
    feed(detector, 45);
    expect(feed(detector, 80), [TiltAction.pass]);
    expect(feed(detector, 45), isEmpty);
    expect(feed(detector, 5), [TiltAction.hit]);
  });

  test('se ajusta a la gravedad que mide cada celular', () {
    // Un sensor que mide un 4 % de más.
    final detector = TiltDetector();
    List<TiltAction> tilt(double degrees) {
      final (x, y, z) = reading(degrees);
      return [
        for (var i = 0; i < 15; i++)
          detector.addSample(x * 1.04, y * 1.04, z * 1.04),
      ].whereType<TiltAction>().toList();
    }

    expect(tilt(0), isEmpty);
    expect(tilt(-36), [TiltAction.hit]);
    expect(tilt(0), isEmpty);
    expect(tilt(36), [TiltAction.pass]);
  });

  test('reset vuelve a calibrar', () {
    final detector = TiltDetector();
    feed(detector, -60);
    detector.reset();
    feed(detector, 0);
    expect(feed(detector, -60), [TiltAction.hit]);
  });
}
