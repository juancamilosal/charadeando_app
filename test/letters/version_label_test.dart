import 'package:charadeando_app/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('5 toques seguidos en la versión abren la prueba de voz', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VersionLabel(onSecret: () => opened++)),
      ),
    );
    final label = find.byType(VersionLabel);
    for (var i = 0; i < 4; i++) {
      await tester.tap(label);
    }
    expect(opened, 0);
    await tester.tap(label);
    expect(opened, 1);
  });
}
