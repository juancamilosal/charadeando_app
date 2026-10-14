import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/category_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:charadeando_app/widgets/category_card.dart';
import 'package:charadeando_app/widgets/premium_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../services/premium_test.dart';
import 'my_categories_test.dart' show MemoryCustomStore;

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required FakeBilling billing,
    MemoryPremiumStore? store,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        customCategoryStoreProvider.overrideWithValue(MemoryCustomStore()),
        clockProvider.overrideWithValue(() => DateTime(2026, 12, 10)),
        allSeasonsProvider.overrideWithValue(false),
        premiumBillingProvider.overrideWithValue(billing),
        premiumStoreProvider.overrideWithValue(store ?? MemoryPremiumStore()),
        promoCodeServiceProvider.overrideWithValue(FakeCodes()),
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

  Finder card(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(CategoryCard));

  Future<void> tapCard(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pump();
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('las de pago llevan candado y al tocarlas se ofrece Premium; '
      'al comprarlo se abren', (tester) async {
    final billing = FakeBilling();
    final container = await pump(tester, billing: billing);
    for (final label in ['Anime', 'Futbolistas', 'Navidad']) {
      expect(card(label).evaluate().single.widget, isA<CategoryCard>());
      expect(
        tester.widget<CategoryCard>(card(label)).locked,
        isTrue,
        reason: label,
      );
    }
    expect(tester.widget<CategoryCard>(card('Animales')).locked, isFalse);

    await tapCard(tester, 'Anime');
    expect(find.text('Desbloquea Anime'), findsOneWidget);
    expect(find.text(r'Solo Anime · $3.900'), findsOneWidget);
    expect(find.text('o mejor'), findsOneWidget);
    expect(find.text(r'Todas las categorías · $14.900'), findsOneWidget);
    // Sin decir cuánto se ahorra: solo los dos precios.
    expect(find.textContaining('Ahorras'), findsNothing);
    expect(find.text('Todo Charadeando'), findsOneWidget);
    expect(find.text('Pago único · sin mensualidades'), findsOneWidget);
    // Sin el sello: todavía no lo tiene.
    expect(find.byType(TodoCharadeandoSeal), findsNothing);
    for (final benefit in premiumBenefits) {
      expect(find.text(benefit), findsOneWidget);
    }
    expect(find.text('Config'), findsNothing);

    await tester.tap(find.text(r'Todas las categorías · $14.900'));
    await tester.pump();
    expect(billing.bought, [null]);
    billing.send(const BillingEvent(BillingStatus.owned));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Desbloquea Anime'), findsNothing);
    expect(find.text('¡Listo! Ya tienes Todo Charadeando.'), findsOneWidget);
    // Ahora lleva el sello dorado en la barra.
    expect(find.byType(TodoCharadeandoSeal), findsOneWidget);
    expect(container.read(premiumUnlockedProvider), isTrue);
    expect(tester.widget<CategoryCard>(card('Anime')).locked, isFalse);
    // Con Todo Charadeando brillan todas, también las gratis.
    expect(tester.widget<CategoryCard>(card('Anime')).shine, isNotNull);
    expect(tester.widget<CategoryCard>(card('Animales')).shine, isNotNull);

    // Ahora sí se juega: se elige cómo jugar.
    await tapCard(tester, 'Anime');
    expect(find.text('Desbloquea Anime'), findsNothing);
    expect(find.text('Personalizada'), findsOneWidget);
  });

  testWidgets('comprar solo una categoría abre esa y las demás siguen con '
      'candado', (tester) async {
    final billing = FakeBilling();
    final container = await pump(tester, billing: billing);
    await tapCard(tester, 'Futbolistas');
    await tester.tap(find.text(r'Solo Futbolistas · $3.900'));
    await tester.pump();
    expect(billing.bought, ['FUTBOLISTAS']);
    billing.send(
      const BillingEvent(BillingStatus.owned, category: 'FUTBOLISTAS'),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Desbloquea Futbolistas'), findsNothing);
    expect(find.text('¡Listo! Ya tienes Futbolistas.'), findsOneWidget);
    expect(tester.widget<CategoryCard>(card('Futbolistas')).locked, isFalse);
    expect(tester.widget<CategoryCard>(card('Anime')).locked, isTrue);
    // La comprada brilla de vez en cuando; las demás, no.
    expect(tester.widget<CategoryCard>(card('Futbolistas')).shine, isNotNull);
    expect(tester.widget<CategoryCard>(card('Anime')).shine, isNull);
    expect(tester.widget<CategoryCard>(card('Animales')).shine, isNull);
    expect(container.read(premiumUnlockedProvider), isFalse);
  });

  testWidgets('sin Google Play avisa que no se puede comprar', (tester) async {
    await pump(tester, billing: FakeBilling(available: false));
    await tapCard(tester, 'Futbolistas');
    // Sin Google Play se ven los precios de respaldo.
    expect(find.text(r'Todas las categorías · $14.900'), findsOneWidget);
    expect(find.text(r'Solo Futbolistas · $3.900'), findsOneWidget);
    await tester.tap(find.text(r'Todas las categorías · $14.900'));
    await tester.pump();
    expect(
      find.textContaining('Las compras no están disponibles'),
      findsOneWidget,
    );
    expect(find.text('Desbloquea Futbolistas'), findsOneWidget);
  });

  testWidgets('un código abre la categoría y cierra la oferta; uno vencido '
      'dice por qué', (tester) async {
    final store = MemoryPremiumStore();
    final container = await pump(tester, billing: FakeBilling(), store: store);
    await tapCard(tester, 'Anime');
    await tester.ensureVisible(find.text('Tengo un código'));
    await tester.pump();
    await tester.tap(find.text('Tengo un código'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Canjear código'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'VIEJO');
    await tester.tap(find.text('Canjear'));
    await tester.pump();
    expect(find.text('Este código ya venció.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'anime2026');
    await tester.tap(find.text('Canjear'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Canjear código'), findsNothing);
    expect(find.text('Desbloquea Anime'), findsNothing);
    expect(find.text('¡Listo! Desbloqueaste Anime.'), findsOneWidget);
    expect(store.saved.codeCategories, {'ANIME'});
    // Solo Anime: las demás de pago siguen con candado.
    expect(tester.widget<CategoryCard>(card('Anime')).locked, isFalse);
    expect(tester.widget<CategoryCard>(card('Futbolistas')).locked, isTrue);
    expect(container.read(premiumUnlockedProvider), isFalse);
  });

  test('el mensaje dice qué se abrió', () {
    expect(
      redeemedMessage(const CodeUnlock(all: true)),
      '¡Listo! Desbloqueaste todo Charadeando.',
    );
    expect(
      redeemedMessage(const CodeUnlock(categories: {'ANIME', 'FUTBOLISTAS'})),
      '¡Listo! Desbloqueaste Anime y Futbolistas.',
    );
    // Gratis, las dos primeras de cada sección; las demás, de pago.
    for (final c in [
      GameCategory.free,
      GameCategory.animals,
      GameCategory.food,
      GameCategory.movies,
      GameCategory.seriesNovels,
      GameCategory.geography,
      GameCategory.places,
      GameCategory.sports,
      GameCategory.soccerTeams,
      GameCategory.vacations,
      GameCategory.halloween,
    ]) {
      expect(c.premium, isFalse, reason: c.label);
    }
    for (final c in [
      GameCategory.objects,
      GameCategory.characters,
      GameCategory.anime,
      GameCategory.historicalFigures,
      GameCategory.footballers,
      GameCategory.christmas,
    ]) {
      expect(c.premium, isTrue, reason: c.label);
    }
  });
}
