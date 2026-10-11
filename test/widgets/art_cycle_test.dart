import 'dart:io';
import 'dart:ui' as ui;

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/widgets/art_cycle.dart';
import 'package:charadeando_app/widgets/category_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un dibujo de mentiras que anota cuándo se anima.
class _Fake implements CycleMember {
  _Fake(this.order, this.log, {this.canPlay = true});

  @override
  final int order;
  final List<int> log;

  @override
  bool canPlay;

  @override
  Future<void> play() async {
    log.add(order);
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('anima uno por uno, en orden, salta los que no se ven y '
      'vuelve a empezar', (tester) async {
    final key = GlobalKey<ArtCycleState>();
    await tester.pumpWidget(ArtCycle(key: key, child: const SizedBox()));
    final log = <int>[];
    final hidden = _Fake(2, log, canPlay: false);
    // Se agregan en desorden: el ciclo sigue el orden de las categorías.
    for (final m in [_Fake(3, log), hidden, _Fake(0, log), _Fake(1, log)]) {
      key.currentState!.add(m);
    }

    // Al abrir la pantalla espera un momento antes del primero.
    await tester.pump(ArtCycle.firstDelay - ArtCycle.pause);
    expect(log, isEmpty);

    // Cada uno tarda 1 s y hay una pausa de medio segundo entre ellos.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 1500));
    }
    expect(log, [0, 1, 3, 0, 1, 3]);

    // Al verse, entra en su turno.
    hidden.canPlay = true;
    log.clear();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 1500));
    }
    expect(log, [0, 1, 2, 3]);
    await tester.pumpWidget(const SizedBox());
  });

  test('el balón de Deportes se queda quieto en el centro', () async {
    final bytes = File(CategoryArt.asset(GameCategory.sports))
        .readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes);
    final rest = CategoryArt.restFrames[GameCategory.sports]!;
    late ui.Image image;
    for (var i = 0; i <= rest; i++) {
      image = (await codec.getNextFrame()).image;
    }
    final data = (await image.toByteData())!;
    var top = image.height;
    var bottom = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        if (data.getUint8((y * image.width + x) * 4 + 3) == 0) continue;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    expect((top + bottom) / 2, closeTo(image.height / 2, 2));
  });

  test('cada categoría con GIF tiene su imagen de reposo', () {
    for (final category in CategoryArt.restFrames.keys) {
      expect(
        File(CategoryArt.restAsset(category)).existsSync(),
        isTrue,
        reason: category.label,
      );
    }
  });
}
