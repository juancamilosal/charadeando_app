import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    bool welcomeSeen = true,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        welcomeSeenProvider.overrideWith(() => WelcomeSeen(welcomeSeen)),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: Routes.splash,
      routes: [
        GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
        GoRoute(
          path: Routes.categories,
          builder: (_, _) => const Text('Categorías'),
        ),
        GoRoute(
          path: Routes.welcome,
          builder: (_, _) => const Text('Bienvenida'),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    // Las imágenes se cargan de verdad antes de mostrarse.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  Finder sparkles() => find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == SplashScreen.sparkleAsset,
  );

  Finder logo() => find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == SplashScreen.logoAsset,
  );

  test('20 destellos de 8% a 30% del ancho, 6 teñidos de los tres colores', () {
    const s = SplashScreen.sparkles;
    expect(s, hasLength(20));
    expect(s.every((d) => d.size >= 0.08 && d.size <= 0.30), isTrue);
    final tinted = s.where((d) => d.tint != null).toList();
    expect(tinted, hasLength(6));
    expect(tinted.map((d) => d.tint).toSet(), {
      SplashScreen.yellow,
      SplashScreen.turquoise,
      SplashScreen.magenta,
    });
    // Ninguno sobre la firma.
    expect(s.every((d) => d.y < 0.9), isTrue);
    // Titilan con ritmos y retrasos distintos.
    expect(s.map((d) => (d.period, d.delay)).toSet(), hasLength(20));
  });

  testWidgets('el logo centrado al 72% del ancho, los destellos y la firma', (
    tester,
  ) async {
    await pump(tester);
    final screen = tester.getSize(find.byType(SplashScreen));
    expect(logo(), findsOneWidget);
    final logoSize = tester.getSize(logo());
    expect(logoSize.width, closeTo(screen.width * 0.72, 1));
    expect(tester.getCenter(logo()).dx, closeTo(screen.width / 2, 1));
    expect(sparkles(), findsNWidgets(20));
    final firma = tester.widget<Text>(find.text('by ValkiriaCode'));
    expect(firma.style!.fontSize, 14);
    expect(firma.style!.fontWeight, FontWeight.w700);
    expect(firma.style!.color!.a, closeTo(0.7, 0.01));
    expect(
      tester.getBottomLeft(find.text('by ValkiriaCode')).dy,
      lessThan(screen.height),
    );
    // Fondo morado de la marca.
    expect(
      tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .any((b) => b.color == SplashScreen.background),
      isTrue,
    );
  });

  testWidgets('el logo entra con escala y opacidad', (tester) async {
    await pump(tester);
    Opacity logoOpacity() => tester.widget<Opacity>(
      find.ancestor(of: logo(), matching: find.byType(Opacity)).first,
    );
    expect(logoOpacity().opacity, lessThan(0.5));
    await tester.pump(const Duration(milliseconds: 700));
    expect(logoOpacity().opacity, 1);
  });

  testWidgets('a los 1,8 s pasa a Categorías', (tester) async {
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('Categorías'), findsNothing);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(find.text('Categorías'), findsOneWidget);
  });

  testWidgets('la primera vez pasa a la bienvenida', (tester) async {
    await pump(tester, welcomeSeen: false);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenida'), findsOneWidget);
  });

  testWidgets('al tocar pasa de una vez', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(SplashScreen));
    await tester.pumpAndSettle();
    expect(find.text('Categorías'), findsOneWidget);
  });

  testWidgets('con "reducir animaciones" el logo no rebota y los destellos '
      'quedan quietos', (tester) async {
    await pump(tester, reduceMotion: true);
    double opacityOfFirstSparkle() => tester
        .widget<Opacity>(
          find.ancestor(of: sparkles().first, matching: find.byType(Opacity)),
        )
        .opacity;
    final before = opacityOfFirstSparkle();
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacityOfFirstSparkle(), before);
    final scale = tester.widget<Transform>(
      find.ancestor(of: logo(), matching: find.byType(Transform)).first,
    );
    expect(scale.transform.getMaxScaleOnAxis(), 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  test('un destello titila suave entre apagado y encendido', () {
    const s = Sparkle(0.5, 0.5, 0.1, period: 2);
    expect(s.glowAt(0), closeTo(0, 1e-9));
    expect(s.glowAt(1), closeTo(1, 1e-9));
    expect(s.glowAt(2), closeTo(0, 1e-9));
    expect(s.glowAt(0.5), closeTo(0.5, 1e-9));
  });
}
