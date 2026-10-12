import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/category_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../screens/my_categories_test.dart' show MemoryCustomStore;

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Routes.categories,
    routes: [
      GoRoute(
        path: Routes.categories,
        builder: (_, _) => const CategoryScreen(),
      ),
      GoRoute(path: Routes.backdrops, builder: (_, _) => const Text('Fondos')),
      GoRoute(
        path: Routes.welcome,
        builder: (_, _) => const Text('Bienvenida'),
      ),
      GoRoute(path: Routes.myVideos, builder: (_, _) => const Text('Videos')),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customCategoryStoreProvider.overrideWithValue(MemoryCustomStore()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('la barra tiene solo Mis videos y Configuración, y el título '
      'cabe en 360 px', (tester) async {
    await _pump(tester, const Size(360, 800));
    expect(find.byTooltip('Mis videos'), findsOneWidget);
    expect(find.byTooltip('Configuración'), findsOneWidget);
    expect(find.byTooltip('Fondos'), findsNothing);
    expect(find.byTooltip('Cómo se juega'), findsNothing);
    expect(find.text('¿Con qué palabras quieren jugar?'), findsNothing);
    expect(find.text('Categorías'), findsNothing);

    final title = tester.getRect(find.text('Selección de categoría'));
    final videos = tester.getRect(find.byTooltip('Mis videos'));
    expect(title.left, greaterThanOrEqualTo(0));
    expect(title.right, lessThanOrEqualTo(videos.left));
  });

  testWidgets('el menú de configuración abre Fondos y Cómo se juega', (
    tester,
  ) async {
    await _pump(tester, const Size(360, 800));
    await tester.tap(find.byTooltip('Configuración'));
    await _settle(tester);
    expect(find.text('Cambia el color de la app'), findsOneWidget);
    expect(find.text('Ver la explicación otra vez'), findsOneWidget);

    await tester.tap(find.text('Fondos'));
    await _settle(tester);
    expect(find.text('Cambia el color de la app'), findsNothing);
    expect(find.text('Fondos'), findsOneWidget);
  });
}
