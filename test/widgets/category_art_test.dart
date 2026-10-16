import 'dart:io';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/widgets/category_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada categoría con dibujo tiene su imagen en la carpeta', () {
    for (final category in CategoryArt.withImage) {
      expect(
        File(CategoryArt.asset(category)).existsSync(),
        isTrue,
        reason: category.label,
      );
    }
    // Ya no quedan GIF.
    expect(
      Directory('assets/img/categorias')
          .listSync()
          .where((f) => f.path.endsWith('.gif')),
      isEmpty,
    );
  });

  test('todas las categorías tienen su dibujo', () {
    // Fotomímica usa su ícono (una cámara) hasta que tenga su imagen.
    expect(
      CategoryArt.withImage,
      containsAll(GameCategory.values.where((c) => !c.photos)),
    );
  });

  testWidgets('Fotomímica, sin imagen todavía, muestra su ícono', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: CategoryArt(category: GameCategory.photoMime, size: 80),
      ),
    );
    expect(find.byIcon(Icons.photo_camera), findsOneWidget);
  });

  testWidgets('muestra la imagen quieta', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: CategoryArt(category: GameCategory.places, size: 80),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/img/categorias/lugares.png',
    );
  });
}
