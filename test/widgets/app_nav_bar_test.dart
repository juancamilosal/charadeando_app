import 'package:charadeando_app/app.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:charadeando_app/widgets/app_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../providers/my_videos_test.dart';
import '../screens/config_screen_test.dart'
    show MemoryConfigStore, MemoryTeamStore;
import '../screens/my_categories_test.dart' show MemoryCustomStore;
import '../screens/roulette_screen_test.dart' show MemoryStore;

/// Sin carpeta de videos de verdad.
class _NoVideos extends VideoService {
  @override
  Future<void> deleteAll() async {}
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        welcomeSeenProvider.overrideWith(() => WelcomeSeen(true)),
        customCategoryStoreProvider.overrideWithValue(MemoryCustomStore()),
        teamStoreProvider.overrideWithValue(MemoryTeamStore()),
        configStoreProvider.overrideWithValue(MemoryConfigStore()),
        punishmentStoreProvider.overrideWithValue(MemoryStore()),
        myVideosStoreProvider.overrideWithValue(MemoryVideosStore()),
        videoGalleryProvider.overrideWithValue(FakeGallery()),
        videoServiceProvider.overrideWithValue(_NoVideos()),
        tvConnectedProvider.overrideWith((ref) => Stream.value(false)),
      ],
      child: const CharadeandoApp(),
    ),
  );
  await _settle(tester);
}

void main() {
  testWidgets('la app abre en Categorías, en el centro de la barra, y cada '
      'pestaña tiene su pantalla', (tester) async {
    await _open(tester);
    expect(find.byType(AppNavBar), findsOneWidget);
    expect(find.text('Selección de categoría'), findsOneWidget);
    final labels = [for (final item in navItems) item.$2];
    expect(labels, ['Ruleta', 'Equipos', 'Categorías', 'Videos', 'Ajustes']);
    // La ruleta tiene ícono de ruleta, no de dado.
    expect(find.byType(RouletteIcon), findsOneWidget);
    expect(find.byIcon(Icons.casino_rounded), findsNothing);
    // Categorías va en el centro.
    final center = tester.getCenter(find.text('Categorías'));
    expect(center.dx, closeTo(1080 / tester.view.devicePixelRatio / 2, 2));
    // Ya no están los íconos de arriba ni el banner de la ruleta.
    expect(find.byTooltip('Mis videos'), findsNothing);
    expect(find.byTooltip('Configuración'), findsNothing);
    expect(find.text('Ruleta de castigos'), findsNothing);

    final screens = {
      'Ruleta': 'Ruleta de castigos',
      'Equipos': 'Crea tu primer equipo',
      'Videos': 'Mis videos',
      'Ajustes': 'Preferencias de juego',
    };
    for (final entry in screens.entries) {
      await tester.tap(
        find.descendant(
          of: find.byType(AppNavBar),
          matching: find.text(entry.key),
        ),
      );
      await _settle(tester);
      expect(find.text(entry.value), findsOneWidget);
      expect(find.byType(AppNavBar), findsOneWidget);
    }
  });

  testWidgets('la barra no se ve en la bienvenida, la configuración, las '
      'palabras ni los resultados', (tester) async {
    await _open(tester);
    final router = GoRouter.of(tester.element(find.byType(AppNavBar)));
    for (final route in [
      Routes.welcome,
      Routes.config,
      Routes.words,
      Routes.turnResult,
      Routes.finalResult,
      Routes.backdrops,
    ]) {
      router.go(route);
      await _settle(tester);
      expect(find.byType(AppNavBar), findsNothing, reason: route);
    }
    router.go(Routes.categories);
    await _settle(tester);
    expect(find.byType(AppNavBar), findsOneWidget);
  });
}
