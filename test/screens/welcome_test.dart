import 'package:charadeando_app/app.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'my_categories_test.dart' show MemoryCustomStore;

/// Recuerda en memoria si ya se vio la bienvenida, sin archivos.
class MemoryWelcomeStore extends WelcomeStore {
  bool value = false;

  @override
  Future<bool> seen() async => value;

  @override
  Future<void> markSeen() async => value = true;
}

/// Abre la app como lo hace `main`: primero lee si ya se vio la bienvenida.
Future<void> _open(WidgetTester tester, MemoryWelcomeStore store) async {
  final seen = await store.seen();
  // Una app nueva, como al volver a abrirla.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        welcomeStoreProvider.overrideWithValue(store),
        welcomeSeenProvider.overrideWith(() => WelcomeSeen(seen)),
        customCategoryStoreProvider.overrideWithValue(MemoryCustomStore()),
      ],
      child: const CharadeandoApp(),
    ),
  );
  await _settle(tester);
}

/// La bienvenida tiene animaciones que se repiten.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

final _welcome = find.text('El juego de charadas que graba tus risas');
final _categories = find.text('Selección de categoría');

void main() {
  testWidgets('la primera vez abre la bienvenida y después, Categorías', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final store = MemoryWelcomeStore();

    await _open(tester, store);
    expect(_welcome, findsOneWidget);
    expect(find.text('Formen equipos y elijan una categoría.'), findsOneWidget);
    expect(_categories, findsNothing);

    await tester.tap(find.text('Listo'));
    await _settle(tester);
    expect(_categories, findsOneWidget);
    expect(store.value, isTrue);

    await _open(tester, store);
    expect(_categories, findsOneWidget);
    expect(_welcome, findsNothing);
  });

  testWidgets('"Cómo se juega" abre la bienvenida y "Listo" vuelve', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final store = MemoryWelcomeStore()..value = true;

    await _open(tester, store);
    expect(_categories, findsOneWidget);
    // Es la primera pantalla: no tiene botón de atrás.
    expect(find.byType(BackButton), findsNothing);

    // Desde Ajustes, en la barra de abajo.
    await tester.tap(find.text('Ajustes'));
    await _settle(tester);
    await tester.tap(find.text('Cómo se juega'));
    await _settle(tester);
    expect(_welcome, findsOneWidget);
    // La bienvenida no lleva la barra de abajo.
    expect(find.text('Equipos'), findsNothing);

    await tester.tap(find.text('Listo'));
    await _settle(tester);
    expect(_welcome, findsNothing);
    expect(find.text('Preferencias de juego'), findsOneWidget);
  });
}
