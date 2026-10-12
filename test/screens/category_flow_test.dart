import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/category_screen.dart';
import 'package:charadeando_app/services/services.dart';
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
        'GEOGRAFIA',
        'LUGARES',
        'PERSONAJES_HISTORICOS',
        'DICHOS_REFRANES',
        'MARCAS',
        'DEPORTES',
        'EQUIPOS_FUTBOL',
        'HALLOWEEN',
        'NAVIDAD',
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
        'Cultura general',
        'Deportes',
        'Especiales',
      ],
    );
    expect(labels(CategorySection.special), ['Navidad']);
    expect(
      [
        for (final c in GameCategory.inSection(
          CategorySection.special,
          DateTime(2026, 10, 15),
        ))
          c.label,
      ],
      ['Halloween'],
    );
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

  test('Navidad solo se ve del 1 de diciembre al 6 de enero y Halloween '
      'en octubre', () {
    List<GameCategory> specials(DateTime date) => [
      for (final (s, list) in GameCategory.sectionsOn(date))
        if (s == CategorySection.special) ...list,
    ];
    for (final (date, expected) in [
      (DateTime(2026, 9, 30), <GameCategory>[]),
      (DateTime(2026, 10, 1), [GameCategory.halloween]),
      (DateTime(2026, 10, 31), [GameCategory.halloween]),
      (DateTime(2026, 11, 1), <GameCategory>[]),
      (DateTime(2026, 11, 30), <GameCategory>[]),
      (DateTime(2026, 12, 1), [GameCategory.christmas]),
      (DateTime(2026, 12, 31), [GameCategory.christmas]),
      (DateTime(2027, 1, 6), [GameCategory.christmas]),
      (DateTime(2027, 1, 7), <GameCategory>[]),
    ]) {
      expect(specials(date), expected, reason: '$date');
    }
  });

  test('ninguna lleva "Nueva" por ahora; solo Halloween sigue en '
      '"Pronto"', () {
    expect(GameCategory.values.where((c) => c.isNew), isEmpty);
    expect(
      [
        for (final c in GameCategory.values)
          if (!c.available) c,
      ],
      [GameCategory.halloween],
    );
  });

  Future<ProviderContainer> pumpCategories(
    WidgetTester tester,
    DateTime today, {
    bool allSeasons = false,
    MemoryCustomStore? customStore,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        customCategoryStoreProvider.overrideWithValue(
          customStore ?? MemoryCustomStore(),
        ),
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

  Finder sectionTitle(String title) => find.descendant(
    of: find.byType(CategorySectionHeader),
    matching: find.text(title),
  );

  testWidgets('Especiales, Halloween y Navidad solo aparecen en su '
      'temporada', (tester) async {
    await pumpCategories(tester, DateTime(2026, 12, 10));
    expect(sectionTitle('Especiales'), findsOneWidget);
    expect(find.text('Solo por temporada'), findsOneWidget);
    expect(find.text('Navidad'), findsOneWidget);
    expect(find.text('8 categorías'), findsOneWidget);

    expect(find.text('Halloween', skipOffstage: false), findsNothing);

    // En octubre, Halloween.
    await tester.pumpWidget(const SizedBox());
    await pumpCategories(tester, DateTime(2026, 10, 12));
    expect(sectionTitle('Especiales'), findsOneWidget);
    expect(find.text('Halloween', skipOffstage: false), findsOneWidget);
    expect(find.text('Navidad', skipOffstage: false), findsNothing);

    // En noviembre, ninguna.
    await tester.pumpWidget(const SizedBox());
    await pumpCategories(tester, DateTime(2026, 11, 10));
    expect(sectionTitle('Especiales'), findsNothing);
    // Libre va arriba, aparte, como una tarjeta.
    expect(find.text('Libre'), findsOneWidget);

    // Para probarlas, se pueden ver todo el año.
    await tester.pumpWidget(const SizedBox());
    await pumpCategories(tester, DateTime(2026, 11, 10), allSeasons: true);
    expect(sectionTitle('Especiales'), findsOneWidget);
    expect(find.text('Halloween', skipOffstage: false), findsOneWidget);
    expect(find.text('Navidad', skipOffstage: false), findsOneWidget);
    expect(sectionTitle('Entretenimiento'), findsOneWidget);
  });

  testWidgets('las de "Pronto" no se juegan', (tester) async {
    // En octubre, para que se vea Halloween, que sigue en "Pronto".
    final container = await pumpCategories(tester, DateTime(2026, 10, 12));
    expect(find.text('Nueva'), findsNothing);
    final halloween = find.text('Halloween');
    await tester.scrollUntilVisible(
      halloween,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Pronto'), findsOneWidget);
    await tester.tap(halloween);
    await tester.pump();
    expect(
      find.text('¡Pronto! Estamos preparando las palabras de Halloween.'),
      findsOneWidget,
    );
    expect(find.text('Partida rápida'), findsNothing);
    expect(
      container.read(gameControllerProvider).config.category,
      isNot(GameCategory.halloween),
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

  testWidgets('"Todas" termina con la sección "Mis categorías"', (
    tester,
  ) async {
    await pumpCategories(
      tester,
      DateTime(2026, 10, 12),
      customStore: MemoryCustomStore(
        CustomCategoriesData(
          categories: [
            CustomCategory(
              id: 'f1',
              name: 'Mi familia',
              words: [for (var i = 0; i < 12; i++) 'Primo $i'],
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    final mine = sectionTitle('Mis categorías');
    await tester.scrollUntilVisible(
      mine,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(mine, findsOneWidget);
    expect(find.text('1 categoría'), findsOneWidget);
    expect(find.text('Mi familia'), findsOneWidget);
    expect(find.text('Nueva\ncategoría'), findsOneWidget);
  });
}
