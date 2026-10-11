import 'dart:io';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/category_intro_screen.dart';
import 'package:charadeando_app/screens/category_screen.dart';
import 'package:charadeando_app/widgets/how_to_play_demo.dart';
import 'package:charadeando_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Carga Fredoka y Nunito de `assets/fonts` para medir los textos como en
/// el celular.
Future<void> loadAppFonts() async {
  Future<void> family(String name, List<String> weights) async {
    final loader = FontLoader(name);
    for (final w in weights) {
      final bytes = File('assets/fonts/${name}_$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await family('Fredoka', ['500Medium', '600SemiBold', '700Bold']);
  await family('Nunito', [
    '400Regular',
    '600SemiBold',
    '700Bold',
    '800ExtraBold',
  ]);
}

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
    await tester.ensureVisible(movies);
    await tester.pump();
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

  testWidgets('el botón "Jugar" se ve sin bajar en un celular normal', (
    tester,
  ) async {
    // Con las fuentes de la app: las de prueba tienen letras mucho más
    // anchas y ocupan más renglones.
    await tester.runAsync(loadAppFonts);
    // 360 x 800, un celular común.
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    for (final category in GameCategory.themed) {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(gameControllerProvider.notifier)
          .configure(
            container
                .read(gameControllerProvider)
                .config
                .copyWith(category: category, wordSource: WordSource.random),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const CategoryIntroScreen(),
          ),
        ),
      );
      await tester.pump();
      final play = find.text('Jugar ${category.label}');
      expect(play, findsOneWidget, reason: category.label);
      expect(
        tester.getRect(play).bottom,
        lessThan(800),
        reason: category.label,
      );
    }
  });

  testWidgets('con un TV conectado, la animación dice que marca el juez', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HowToPlayDemo(tvMode: true))),
    );
    expect(
      find.text('El juez toca ¡Correcto! o Pasar en el celular.'),
      findsOneWidget,
    );
    expect(find.textContaining('Inclina el celular'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
