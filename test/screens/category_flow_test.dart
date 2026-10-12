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
  test('las categorías del juego, con los códigos de Directus', () {
    expect(
      [for (final c in GameCategory.themed) c.code],
      [
        'ANIMALES',
        'COMIDA',
        'OBJETOS',
        'PROFESIONES',
        'ACCIONES',
        'PELICULAS',
        'SERIES_NOVELAS',
        'PERSONAJES',
        'SUPERHEROES',
        'DIBUJOS_ANIMADOS',
        'VIDEOJUEGOS',
        'MUSICA',
        'CELEBRIDADES',
        'NAVIDAD',
        'GEOGRAFIA',
        'LUGARES',
        'PERSONAJES_HISTORICOS',
        'DICHOS_REFRANES',
        'MARCAS',
        'DEPORTES',
        'EQUIPOS_FUTBOL',
      ],
    );
    expect(GameCategory.byCode('COMIDA'), GameCategory.food);
    expect(GameCategory.byCode('NAVIDAD'), GameCategory.christmas);
  });

  test('cada sección tiene sus categorías, en orden', () {
    final december = DateTime(2026, 12, 10);
    List<String> labels(CategorySection s) => [
      for (final c in GameCategory.inSection(s, december)) c.label,
    ];
    expect(
      [for (final (s, _) in GameCategory.sectionsOn(december)) s.title],
      [
        'Clásicos',
        'Entretenimiento',
        'Especiales',
        'Cultura general',
        'Deportes',
      ],
    );
    expect(labels(CategorySection.special), ['Navidad']);
    expect(labels(CategorySection.entertainment), [
      'Películas',
      'Series y novelas',
      'Personajes',
      'Superhéroes',
      'Dibujos animados',
      'Videojuegos',
      'Música y canciones',
      'Celebridades',
    ]);
    expect(labels(CategorySection.culture), [
      'Geografía',
      'Lugares',
      'Personajes históricos',
      'Dichos y refranes',
      'Marcas',
    ]);
    expect(labels(CategorySection.sports), ['Deportes', 'Equipos de fútbol']);
    expect(labels(CategorySection.classics), [
      'Animales',
      'Comida',
      'Objetos',
      'Profesiones',
      'Acciones',
    ]);
    // Cada una en una sola sección; Libre en ninguna.
    expect(GameCategory.free.section, isNull);
    for (final c in GameCategory.themed) {
      expect(c.section, isNotNull, reason: c.label);
    }
  });

  test('Navidad solo se ve del 1 de diciembre al 6 de enero', () {
    for (final (date, shown) in [
      (DateTime(2026, 11, 30), false),
      (DateTime(2026, 12, 1), true),
      (DateTime(2026, 12, 31), true),
      (DateTime(2027, 1, 6), true),
      (DateTime(2027, 1, 7), false),
      (DateTime(2026, 10, 31), false),
    ]) {
      expect(GameCategory.christmas.shownOn(date), shown, reason: '$date');
      expect(
        GameCategory.sectionsOn(date)
            .any((s) => s.$1 == CategorySection.special),
        shown,
        reason: '$date',
      );
    }
    // Otra especial se arma igual, por ejemplo Halloween en octubre.
    const halloween = Season((10, 1), (10, 31));
    expect(halloween.contains(DateTime(2026, 10, 15)), isTrue);
    expect(halloween.contains(DateTime(2026, 11, 1)), isFalse);
  });

  test('las nueve nuevas llevan "Nueva" y están en "Pronto"', () {
    final fresh = [
      for (final c in GameCategory.values)
        if (c.isNew) c,
    ];
    expect(fresh, hasLength(9));
    expect(fresh.every((c) => !c.available), isTrue);
    expect(
      GameCategory.values.where((c) => !c.isNew).every((c) => c.available),
      isTrue,
    );
  });

  Future<ProviderContainer> pumpCategories(
    WidgetTester tester,
    DateTime today, {
    bool allSeasons = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        customCategoryStoreProvider.overrideWithValue(MemoryCustomStore()),
        clockProvider.overrideWithValue(() => today),
        allSeasonsProvider.overrideWithValue(allSeasons),
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
    return container;
  }

  // Los títulos de sección se dibujan dos veces: el borde y la letra.
  Finder sectionTitle(String title) => find.descendant(
    of: find.byType(CategorySectionHeader),
    matching: find.text(title),
  );

  testWidgets('Especiales y Navidad solo aparecen en su temporada', (
    tester,
  ) async {
    await pumpCategories(tester, DateTime(2026, 12, 10));
    expect(sectionTitle('Especiales'), findsNWidgets(2));
    expect(find.text('Solo por temporada'), findsOneWidget);
    expect(find.text('Navidad'), findsOneWidget);
    expect(find.text('8 categorías'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await pumpCategories(tester, DateTime(2026, 10, 12));
    expect(sectionTitle('Especiales'), findsNothing);
    expect(find.text('Navidad'), findsNothing);
    // Libre va arriba, aparte, como una tarjeta.
    expect(find.text('Libre'), findsOneWidget);

    // Para probarlas, se pueden ver todo el año.
    await tester.pumpWidget(const SizedBox());
    await pumpCategories(tester, DateTime(2026, 10, 12), allSeasons: true);
    expect(sectionTitle('Especiales'), findsNWidgets(2));
    expect(find.text('Navidad'), findsOneWidget);
    expect(sectionTitle('Entretenimiento'), findsNWidgets(2));
  });

  testWidgets('las nuevas llevan "Nueva" y las de "Pronto" no se juegan', (
    tester,
  ) async {
    final container = await pumpCategories(tester, DateTime(2026, 10, 12));
    // En la parte de arriba: Series y novelas, Personajes, Superhéroes,
    // Dibujos animados, Videojuegos y Música.
    expect(find.text('Nueva'), findsWidgets);
    expect(find.text('Pronto'), findsWidgets);
    final series = find.text('Series y novelas');
    await tester.ensureVisible(series);
    await tester.pump();
    await tester.tap(series);
    await tester.pump();
    expect(
      find.text(
        '¡Pronto! Estamos preparando las palabras de Series y novelas.',
      ),
      findsOneWidget,
    );
    expect(find.text('Partida rápida'), findsNothing);
    expect(
      container.read(gameControllerProvider).config.category,
      isNot(GameCategory.seriesNovels),
    );
  });

  testWidgets('al tocar una categoría se elige rápida o personalizada; '
      'personalizada va a la configuración, sin grupos', (tester) async {
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

    // Pregunta si es una partida rápida o personalizada.
    expect(find.text('Partida rápida'), findsOneWidget);
    await tester.tap(find.text('Personalizada'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Config'), findsOneWidget);
    final config = container.read(gameControllerProvider).config;
    expect(config.category, GameCategory.food);
    expect(config.wordSource, WordSource.random);
    expect(config.inGroups, isFalse);
  });
}
