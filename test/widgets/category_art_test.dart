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

  testWidgets('muestra la imagen quieta, o el ícono si no tiene', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            CategoryArt(category: GameCategory.places, size: 80),
            CategoryArt(category: GameCategory.videogames, size: 80),
          ],
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/img/categorias/lugares.png',
    );
    expect(find.byIcon(Icons.sports_esports), findsOneWidget);
  });
}
