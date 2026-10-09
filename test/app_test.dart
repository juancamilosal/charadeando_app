import 'package:charadeando_app/app.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// La bienvenida tiene animaciones que se repiten, así que se avanza el
/// tiempo a mano en vez de esperar a que todo se detenga.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('del inicio se pasa por categorías hasta la configuración', (
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
    expect(find.text('Categorías'), findsWidgets);
    expect(find.text('Pronto'), findsNWidgets(7));

    await tester.tap(find.text('Libre'));
    await settle(tester);
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
