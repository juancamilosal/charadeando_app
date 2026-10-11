import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/category_intro_screen.dart';
import 'package:charadeando_app/screens/category_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('cada categoría explica cómo se juega con sus ejemplos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: Routes.categories,
      routes: [
        GoRoute(
          path: Routes.categories,
          builder: (_, _) => const CategoryScreen(),
        ),
        GoRoute(
          path: Routes.categoryIntro,
          builder: (_, _) => const CategoryIntroScreen(),
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

    final movies = find.text('Películas');
    await tester.scrollUntilVisible(
      movies,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(movies);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('¿Cómo se juega?'), findsOneWidget);
    // El ejemplo animado usa palabras de la categoría, letra por letra.
    expect(find.text('K'), findsOneWidget);
    expect(find.textContaining('describe la película'), findsWidgets);
    final config = container.read(gameControllerProvider).config;
    expect(config.category, GameCategory.movies);
    expect(config.wordSource, WordSource.random);

    final play = find.text('Jugar Películas');
    await tester.scrollUntilVisible(
      play,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(play);
    await tester.pump();
    await tester.tap(play);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Config'), findsOneWidget);
  });
}
