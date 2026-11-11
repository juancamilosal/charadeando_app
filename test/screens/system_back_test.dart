import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/auto_words_screen.dart';
import 'package:charadeando_app/screens/config_screen.dart';
import 'package:charadeando_app/screens/free_mode_screen.dart';
import 'package:charadeando_app/screens/word_entry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'config_screen_test.dart' show MemoryConfigStore, MemoryTeamStore;

/// Abre [initial] (como lo abre la app, con `go`, sin nada debajo) y toca
/// el botón atrás del celular.
Future<void> _pressBack(
  WidgetTester tester,
  String initial,
  Widget screen, {
  GameConfig config = const GameConfig(),
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      tvConnectedProvider.overrideWith((ref) => Stream.value(false)),
      configStoreProvider.overrideWithValue(MemoryConfigStore()),
      teamStoreProvider.overrideWithValue(MemoryTeamStore()),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameControllerProvider.notifier).configure(config);
  Widget placeholder(String name) => Scaffold(body: Text(name));
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      for (final (path, name) in [
        (Routes.categories, 'Categorías'),
        (Routes.freeMode, 'Libre'),
        (Routes.config, 'Configuración'),
      ])
        GoRoute(
          path: path,
          builder: (_, _) => path == initial ? screen : placeholder(name),
        ),
      GoRoute(path: initial, builder: (_, _) => screen),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  // El botón atrás de Android.
  final handled = await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  // La app lo maneja: no se cierra hacia el fondo.
  expect(handled, isTrue);
}

void main() {
  testWidgets('atrás en la configuración vuelve a Categorías', (tester) async {
    await _pressBack(
      tester,
      Routes.config,
      const ConfigScreen(),
      config: const GameConfig(category: GameCategory.animals),
    );
    expect(find.text('Categorías'), findsOneWidget);
  });

  testWidgets('atrás en la configuración de Libre vuelve a Libre', (
    tester,
  ) async {
    await _pressBack(tester, Routes.config, const ConfigScreen());
    expect(find.text('Libre'), findsOneWidget);
  });

  testWidgets('atrás en Libre vuelve a Categorías', (tester) async {
    await _pressBack(tester, Routes.freeMode, const FreeModeScreen());
    expect(find.text('Categorías'), findsOneWidget);
  });

  testWidgets('atrás al escribir las palabras vuelve a la configuración', (
    tester,
  ) async {
    await _pressBack(
      tester,
      Routes.words,
      const WordEntryScreen(),
      config: const GameConfig(groups: [Group('Tigres'), Group('Águilas')]),
    );
    expect(find.text('Configuración'), findsOneWidget);
  });

  testWidgets('atrás mientras se descargan las palabras vuelve a la '
      'configuración', (tester) async {
    await _pressBack(
      tester,
      Routes.autoWords,
      const AutoWordsScreen(),
      config: const GameConfig(
        category: GameCategory.animals,
        wordSource: WordSource.random,
      ),
    );
    expect(find.text('Configuración'), findsOneWidget);
  });
}
