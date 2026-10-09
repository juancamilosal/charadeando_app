import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/screens/word_entry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el ojo muestra y oculta cada palabra', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(gameControllerProvider.notifier)
        .configure(const GameConfig(groups: [Group('A'), Group('B')]));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WordEntryScreen()),
      ),
    );
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'El Rey León');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('El Rey León'), findsNothing);

    await tester.tap(find.byTooltip('Mostrar'));
    await tester.pump();
    expect(find.text('1. El Rey León'), findsOneWidget);

    await tester.tap(find.byTooltip('Ocultar'));
    await tester.pump();
    expect(find.textContaining('El Rey León'), findsNothing);
  });
}
