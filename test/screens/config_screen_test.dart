import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/screens/config_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rellena la configuración con los datos de prueba', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(gameControllerProvider.notifier)
        .configure(
          const GameConfig(
            groups: [Group('X'), Group('Y'), Group('Z')],
            rounds: 5,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ConfigScreen()),
      ),
    );
    await tester.tap(find.text('Rellenar datos de prueba'));
    await tester.pump();

    final config = TestData.config;
    // Los datos de prueba tienen 2 grupos y 2 rondas: el mismo número.
    expect(config.groupCount, config.rounds);
    expect(find.text('${config.rounds}'), findsNWidgets(2));
    expect(find.text('${config.turnDuration.inSeconds} s'), findsOneWidget);
    for (final group in config.groups) {
      await tester.scrollUntilVisible(
        find.text(group.name),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(group.name), findsOneWidget);
    }
    expect(find.text('Z'), findsNothing);
  });
}
