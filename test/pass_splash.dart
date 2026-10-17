import 'package:charadeando_app/screens/splash_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// La app abre en la pantalla de carga: se toca para pasar de una vez.
Future<void> passSplash(WidgetTester tester) async {
  await tester.pump();
  if (find.byType(SplashScreen).evaluate().isEmpty) return;
  await tester.tap(find.byType(SplashScreen), warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}
