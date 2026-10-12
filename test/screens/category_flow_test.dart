import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/category_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'my_categories_test.dart' show MemoryCustomStore;

void main() {
  test('las 12 categorías del juego, con los códigos de Directus', () {
    expect(
      [for (final c in GameCategory.themed) c.code],
      [
        'ANIMALES',
        'GEOGRAFIA',
        'PELICULAS',
        'CELEBRIDADES',
        'MARCAS',
        'DEPORTES',
        'EQUIPOS_FUTBOL',
        'OBJETOS',
        'COMIDA',
        'PROFESIONES',
        'ACCIONES',
        'LUGARES',
      ],
    );
    expect(GameCategory.byCode('COMIDA'), GameCategory.food);
  });

  testWidgets('al tocar una categoría va directo a la configuración, sin '
      'grupos', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        customCategoryStoreProvider.overrideWithValue(MemoryCustomStore()),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: Routes.categories,
      routes: [
        GoRoute(
          path: Routes.categories,
          builder: (_, _) => const CategoryScreen(),
        ),
        GoRoute(path: Routes.config, builder: (_, _) => const Text('Config')),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    final food = find.text('Comida');
    await tester.scrollUntilVisible(
      food,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(food);
    await tester.pump();
    await tester.tap(food);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Config'), findsOneWidget);
    final config = container.read(gameControllerProvider).config;
    expect(config.category, GameCategory.food);
    expect(config.wordSource, WordSource.random);
    expect(config.inGroups, isFalse);
  });
}
