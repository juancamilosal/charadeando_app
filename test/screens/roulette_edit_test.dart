import 'dart:math';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/screens/roulette_screen.dart';
import 'package:charadeando_app/widgets/punishment_roulette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'roulette_screen_test.dart' show MemoryStore;

void main() {
  testWidgets('el recuadro del castigo deja editarlo y quitarlo', (
    tester,
  ) async {
    String? edited;
    var removed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPunishmentField(
              context,
              'Bailar sin música',
              2,
              onEdit: (text) => edited = text,
              onRemove: () => removed = true,
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Campo 3'), findsOneWidget);
    expect(find.text('Bailar sin música'), findsOneWidget);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('castigo')),
      'Cantar el himno',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(edited, 'Cantar el himno');
    expect(find.text('Campo 3'), findsNothing);

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Quitar este castigo?'), findsOneWidget);
    await tester.tap(find.text('Quitar').last);
    await tester.pumpAndSettle();
    expect(removed, isTrue);
  });

  testWidgets('sin acciones, el recuadro solo muestra el castigo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showPunishmentField(context, 'Contar un chiste', 0),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Editar'), findsNothing);
    expect(find.text('Quitar'), findsNothing);
  });

  testWidgets('editar o quitar un castigo de la app pasa a "Jugadores y app" '
      'con los mismos castigos que se ven, y se guarda', (tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    addTearDown(tester.view.reset);
    final store = MemoryStore()
      ..saved = const RouletteSetup(
        source: PunishmentSource.system,
        punishments: ['A', 'B', 'C', 'D'],
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [punishmentStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RouletteSetupView(onSpin: (_, _) {}, random: Random(1)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    PunishmentRoulette wheel() =>
        tester.widget<PunishmentRoulette>(find.byType(PunishmentRoulette));
    expect(wheel().punishments, ['A', 'B', 'C', 'D']);

    wheel().onEditField!(1, 'Cantar');
    await tester.pumpAndSettle();
    expect(wheel().punishments, ['A', 'Cantar', 'C', 'D']);
    expect(store.saved!.source, PunishmentSource.mixed);
    expect(store.saved!.written, ['A', 'Cantar', 'C', 'D']);

    wheel().onEditField!(0, null);
    await tester.pumpAndSettle();
    expect(wheel().punishments, ['Cantar', 'C', 'D']);
    expect(store.saved!.punishments, ['Cantar', 'C', 'D']);
  });
}
