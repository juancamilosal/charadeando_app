import 'package:charadeando_app/widgets/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Future<bool>> open(WidgetTester tester) async {
    late Future<bool> answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => answer = showUpdateReady(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('"Actualizar" responde que sí', (tester) async {
    final answer = await open(tester);
    expect(find.text('¡Hay una versión nueva!'), findsOneWidget);
    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();
    expect(await answer, isTrue);
  });

  testWidgets('"Más tarde" responde que no', (tester) async {
    final answer = await open(tester);
    await tester.tap(find.text('Más tarde'));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);
  });
}
