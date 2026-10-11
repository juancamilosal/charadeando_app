import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/category_intro_screen.dart';
import 'package:charadeando_app/screens/category_screen.dart';
import 'package:charadeando_app/screens/custom_category_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// "Mis categorías" en memoria, sin archivos.
class MemoryCustomStore extends CustomCategoryStore {
  MemoryCustomStore([this.data = const CustomCategoriesData()]);

  CustomCategoriesData data;

  @override
  Future<CustomCategoriesData> load() async => data;

  @override
  Future<void> save(CustomCategoriesData data) async => this.data = data;
}

final _office = CustomCategory(
  id: 'o1',
  name: 'La oficina',
  colorIndex: 8,
  iconKey: 'work',
  words: [for (var i = 0; i < 12; i++) 'Palabra $i'],
);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  MemoryCustomStore store,
) async {
  tester.view.physicalSize = const Size(1080, 3600);
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [customCategoryStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: Routes.categories,
    routes: [
      GoRoute(
        path: Routes.categories,
        builder: (_, _) => const CategoryScreen(),
      ),
      GoRoute(
        path: Routes.customCategory,
        builder: (_, state) =>
            CustomCategoryScreen(category: state.extra as CustomCategory?),
      ),
      GoRoute(
        path: Routes.categoryIntro,
        builder: (_, _) => const CategoryIntroScreen(),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  testWidgets('el selector "Todas | Mías" cambia lo que se muestra y se '
      'recuerda', (tester) async {
    final store = MemoryCustomStore(
      CustomCategoriesData(categories: [_office]),
    );
    await _pump(tester, store);
    expect(find.text('Animales'), findsOneWidget);
    expect(find.text('La oficina'), findsNothing);

    await tester.tap(find.text('Mías'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('La oficina'), findsOneWidget);
    expect(find.text('12 palabras'), findsOneWidget);
    expect(find.text('Nueva categoría'), findsOneWidget);
    expect(find.text('Animales'), findsNothing);
    expect(store.data.tab, CategoryTab.mine);

    await tester.tap(find.text('Todas'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Animales'), findsOneWidget);
    expect(store.data.tab, CategoryTab.all);
  });

  testWidgets('sin categorías propias invita a crear la primera', (
    tester,
  ) async {
    await _pump(
      tester,
      MemoryCustomStore(const CustomCategoriesData(tab: CategoryTab.mine)),
    );
    expect(
      find.text(
        'Crea una categoría con las palabras de tu familia o tus amigos',
      ),
      findsOneWidget,
    );
    expect(find.text('Crear mi primera categoría'), findsOneWidget);
  });

  testWidgets('crear una categoría pegando palabras y jugarla', (tester) async {
    final store = MemoryCustomStore(
      const CustomCategoriesData(tab: CategoryTab.mine),
    );
    final container = await _pump(tester, store);
    await tester.tap(find.text('Crear mi primera categoría'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva categoría'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('nombre')), 'Mi familia');
    final words = find.byKey(const ValueKey('palabras'));
    await tester.ensureVisible(words);
    await tester.enterText(words, 'Tía Rosa, Abuelo\nToby, tia rosa');
    await tester.tap(find.byTooltip('Agregar'));
    await tester.pump();
    expect(find.text('Ya estaban: tia rosa'), findsOneWidget);
    expect(
      find.text('Te faltan 7 palabras para poder jugar (mínimo 10).'),
      findsOneWidget,
    );

    await tester.enterText(
      words,
      'Primo Juan, Navidad, Finca, Arepa, Sancocho, Novela, Chisme',
    );
    await tester.tap(find.byTooltip('Agregar'));
    await tester.pump();
    expect(find.text('¡Lista para jugar!'), findsOneWidget);

    // Se espera a que el aviso de repetidas se cierre para que no tape.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    final create = find.text('Crear categoría');
    await tester.scrollUntilVisible(
      create,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();

    final saved = store.data.categories.single;
    expect(saved.name, 'Mi familia');
    expect(saved.words, hasLength(10));

    // Al tocarla se juega como cualquier categoría, con sus palabras.
    await tester.tap(find.text('Mi familia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Jugar Mi familia'), findsOneWidget);
    final config = container.read(gameControllerProvider).config;
    expect(config.customCategory?.id, saved.id);
    expect(config.wordSource, WordSource.random);
  });

  testWidgets('en el editor las palabras se ven completas, aunque sean '
      'largas', (tester) async {
    tester.view.physicalSize = const Size(960, 3600);
    addTearDown(tester.view.reset);
    const long = 'Una palabra larguísima de cuarenta letra';
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CustomCategoryScreen(
            category: CustomCategory(
              id: '1',
              name: 'Mi familia',
              words: const ['Tía Rosa', long],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tía Rosa'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tía Rosa'), findsOneWidget);
    final p = tester.renderObject<RenderParagraph>(find.text(long));
    expect(p.maxLines, isNull);
    expect(p.didExceedMaxLines, isFalse);
  });
}
