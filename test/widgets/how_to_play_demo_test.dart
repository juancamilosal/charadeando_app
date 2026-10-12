import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/widgets/how_to_play_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('con un TV conectado, la animación dice que marca el juez', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HowToPlayDemo(tvMode: true))),
    );
    expect(
      find.text('El juez toca ¡Correcto! o Pasar en el celular.'),
      findsOneWidget,
    );
    expect(find.textContaining('Inclina el celular'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('con el controlador Toque, explica que se toca la pantalla', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HowToPlayDemo(controller: PlayController.touch)),
      ),
    );
    expect(find.textContaining('Toca a la derecha'), findsOneWidget);
    expect(find.textContaining('Inclina el celular'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
