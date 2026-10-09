import 'package:charadeando_app/app.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  testWidgets('del inicio se llega a la configuración pasando por Libre', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [premiumUnlockedProvider.overrideWithValue(false)],
        child: const CharadeandoApp(),
      ),
    );
    expect(find.text('Charadeando'), findsOneWidget);

    await tester.tap(find.text('Listo'));
    await settle(tester);
    expect(find.text('Pronto'), findsNWidgets(7));

    await tester.tap(find.text('Libre'));
    await settle(tester);
    expect(find.text('¿Cómo se juega?'), findsOneWidget);
    expect(find.text('PALABRA SECRETA'), findsOneWidget);

    await tapVisible(tester, 'Palabras manuales');
    expect(find.text('Configuración'), findsOneWidget);

    final premium = find.text('Full HD (1080p) · Premium');
    await tester.scrollUntilVisible(
      premium,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(premium, findsOneWidget);
  });
}
