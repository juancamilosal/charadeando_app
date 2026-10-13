import 'package:charadeando_app/widgets/tap_sounds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('suena al tocar un botón, no al tocar el fondo, al deslizar '
      'ni en uno deshabilitado', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          splashFactory: TapSoundSplashFactory(onTap: () => taps++),
        ),
        home: Scaffold(
          body: ListView(
            children: [
              FilledButton(onPressed: () {}, child: const Text('Botón')),
              const FilledButton(onPressed: null, child: Text('Apagado')),
              ListTile(title: const Text('Fila'), onTap: () {}),
              const SizedBox(height: 300, child: Text('Fondo')),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Botón'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    await tester.tap(find.text('Fila'));
    await tester.pumpAndSettle();
    expect(taps, 2);
    await tester.tap(find.text('Apagado'), warnIfMissed: false);
    await tester.tap(find.text('Fondo'));
    await tester.pumpAndSettle();
    expect(taps, 2);
    // Deslizar sobre el botón no suena.
    await tester.drag(find.text('Botón'), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(taps, 2);
  });
}
