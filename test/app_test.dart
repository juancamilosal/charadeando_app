import 'package:charadeando_app/app.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('de la bienvenida se pasa a la configuración', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [premiumUnlockedProvider.overrideWithValue(false)],
        child: const CharadeandoApp(),
      ),
    );
    expect(find.text('Charadeando'), findsOneWidget);

    await tester.tap(find.text('Jugar'));
    await tester.pumpAndSettle();
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
