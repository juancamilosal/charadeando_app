import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/category_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:charadeando_app/widgets/combine_categories_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../screens/my_categories_test.dart' show MemoryCustomStore;

/// Combinación guardada en memoria, sin archivos.
class MemoryMixStore extends MixStore {
  SavedMix saved = const SavedMix();

  @override
  Future<SavedMix> load() async => saved;

  @override
  Future<void> save(SavedMix mix) async => saved = mix;
}

final _family = CustomCategory(
  id: 'f1',
  name: 'Mi familia',
  words: [for (var i = 0; i < 12; i++) 'Primo $i'],
);
final _office = CustomCategory(
  id: 'o1',
  name: 'La oficina',
  words: const ['Jefe', 'Café'],
);

Finder _inSheet(Finder finder) =>
    find.descendant(of: find.byType(CombineCategoriesSheet), matching: finder);

void main() {
  testWidgets('combina categorías: mínimo 2, sin Libre y sin las bloqueadas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final mixStore = MemoryMixStore();
    final container = ProviderContainer(
      overrides: [
        customCategoryStoreProvider.overrideWithValue(
          MemoryCustomStore(
            CustomCategoriesData(categories: [_family, _office]),
          ),
        ),
        mixStoreProvider.overrideWithValue(mixStore),
        premiumUnlockedProvider.overrideWithValue(false),
        premiumCategoriesProvider.overrideWithValue({GameCategory.brands}),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 12)),
        allSeasonsProvider.overrideWithValue(false),
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

    final button = find.text('Combinar categorías');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    // La ruleta de la pantalla se mueve sin parar: no se espera a que todo
    // se detenga.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(_inSheet(find.text('Libre')), findsNothing);
    expect(_inSheet(find.text('Entretenimiento')), findsOneWidget);
    expect(find.text('Elige al menos 2 categorías'), findsOneWidget);

    Future<void> showInSheet(String text, {bool up = false}) async {
      await tester.scrollUntilVisible(
        _inSheet(find.text(text)),
        up ? -200 : 200,
        scrollable: _inSheet(find.byType(Scrollable)).first,
      );
      await tester.pump();
    }

    // Clásicos va primero.
    expect(_inSheet(find.text('Clásicos')), findsOneWidget);

    await showInSheet('Animales', up: true);
    await tester.tap(_inSheet(find.text('Animales')));
    await tester.pump();
    expect(find.text('Elige al menos 2 categorías'), findsOneWidget);

    // Marcas es premium y no está desbloqueada: avisa y no se marca.
    await showInSheet('Marcas');
    expect(_inSheet(find.byIcon(Icons.lock)), findsOneWidget);
    await tester.tap(_inSheet(find.text('Marcas')));
    await tester.pump();
    expect(find.text('Para jugar Marcas necesitas premium.'), findsOneWidget);
    expect(find.text('Elige al menos 2 categorías'), findsOneWidget);

    // La oficina tiene menos de 10 palabras.
    final office = _inSheet(find.text('La oficina'));
    await tester.scrollUntilVisible(
      office,
      200,
      scrollable: _inSheet(find.byType(Scrollable)).first,
    );
    expect(_inSheet(find.text('Mis categorías')), findsOneWidget);
    expect(_inSheet(find.text('Faltan palabras')), findsOneWidget);
    await tester.tap(office);
    await tester.pump();
    expect(find.text('Elige al menos 2 categorías'), findsOneWidget);

    await tester.tap(_inSheet(find.text('Mi familia')));
    await tester.pump();
    final start = find.text('Empezar a jugar · 2 categorías');
    expect(start, findsOneWidget);

    await tester.tap(start);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Personalizada'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Config'), findsOneWidget);
    final config = container.read(gameControllerProvider).config;
    expect(config.isMix, isTrue);
    expect(config.mixCategories, [GameCategory.animals]);
    expect(config.mixCustom.single.id, 'f1');
    expect(config.wordSource, WordSource.random);
    expect(config.categoryLabel, 'Mezcla: Animales y Mi familia');
    expect(mixStore.saved.categories, ['ANIMALES']);
    expect(mixStore.saved.custom, ['f1']);
  });

  testWidgets('recuerda la última combinación', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final mixStore = MemoryMixStore()
      ..saved = const SavedMix(
        categories: ['PELICULAS', 'DEPORTES'],
        custom: ['f1', 'o1'],
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customCategoryStoreProvider.overrideWithValue(
            MemoryCustomStore(
              CustomCategoriesData(categories: [_family, _office]),
            ),
          ),
          mixStoreProvider.overrideWithValue(mixStore),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCombineCategories(context),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    // La oficina ya no se puede jugar (le faltan palabras): no se marca.
    expect(find.text('Empezar a jugar · 3 categorías'), findsOneWidget);
  });
}
