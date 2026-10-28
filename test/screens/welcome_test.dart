import 'package:charadeando_app/app.dart';
import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/screens/welcome_screen.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'my_categories_test.dart' show MemoryCustomStore;
import '../pass_splash.dart';

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
  await passSplash(tester);
  await _settle(tester);
}

/// La bienvenida tiene animaciones que se repiten.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

final _welcome = find.text('Muchas categorías para jugar');
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
    expect(_categories, findsNothing);

    // Ocho pantallas con "Continuar"; la última, "¡Vamos a jugar!".
    for (final title in [
      'Cómo empezar',
      '¿Lo has acertado?',
      '¿No puedes adivinar?',
      'Jueguen por equipos',
      'Castiga al equipo que pierda',
      'Modo TV',
      '¡Listos para divertirse!',
    ]) {
      await tester.tap(find.text('Continuar'));
      await _settle(tester);
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Omitir'), findsNothing);
    await tester.tap(find.text('¡Vamos a jugar!'));
    await _settle(tester);
    expect(_categories, findsOneWidget);
    expect(store.value, isTrue);

    await _open(tester, store);
    expect(_categories, findsOneWidget);
    expect(_welcome, findsNothing);
  });

  testWidgets('"Cómo se juega" abre la bienvenida y "Omitir" vuelve', (
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
    await tester.scrollUntilVisible(
      find.text('Cómo se juega'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Cómo se juega'));
    await _settle(tester);
    await tester.tap(find.text('Cómo se juega'));
    await _settle(tester);
    expect(_welcome, findsOneWidget);
    // La bienvenida no lleva la barra de abajo.
    expect(find.text('Equipos'), findsNothing);

    await tester.tap(find.text('Omitir'));
    await _settle(tester);
    expect(_welcome, findsNothing);
    // De vuelta en Ajustes, donde quedó la lista.
    expect(find.text('Cómo se juega'), findsOneWidget);
  });

  testWidgets('con el controlador Toque, explica que se toca la pantalla', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsController(
              const AppSettings(controller: PlayController.touch),
            ),
          ),
        ],
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );
    await _settle(tester);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Continuar'));
      await _settle(tester);
    }
    expect(
      find.text('Toca la derecha de la pantalla y suma un punto.'),
      findsOneWidget,
    );
  });
}
