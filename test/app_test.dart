import 'package:charadeando_app/app.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens/welcome_test.dart' show MemoryWelcomeStore;
import 'pass_splash.dart';

/// Varias pantallas tienen animaciones que se repiten, así que se avanza el
/// tiempo a mano en vez de esperar a que todo se detenga.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> tapVisible(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  testWidgets(
    'la primera vez, de la bienvenida se llega a la configuración por Libre',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            premiumUnlockedProvider.overrideWithValue(false),
            welcomeStoreProvider.overrideWithValue(MemoryWelcomeStore()),
          ],
          child: const CharadeandoApp(),
        ),
      );
      await passSplash(tester);
      // "Cómo se juega" empieza por las categorías.
      expect(find.text('Muchas categorías para jugar'), findsOneWidget);

      await tester.tap(find.text('Omitir'));
      await settle(tester);

      await tester.tap(find.text('Libre'));
      await settle(tester);
      expect(find.text('¿Cómo quieren las palabras?'), findsOneWidget);

      await tapVisible(tester, 'Las escribimos');
      // Pregunta si es una partida rápida o personalizada.
      expect(find.text('Partida rápida'), findsOneWidget);
      await tapVisible(tester, 'Personalizada');
      expect(find.text('Configuración'), findsOneWidget);
      // El video se elige antes del turno, no en la configuración.
      expect(find.text('Resolución', skipOffstage: false), findsNothing);
    },
  );
}
