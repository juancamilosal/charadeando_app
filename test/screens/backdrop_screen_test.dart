import 'dart:io';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/backdrop_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:charadeando_app/theme.dart';
import 'package:charadeando_app/widgets/shine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Fondo guardado en memoria, sin archivos.
class MemoryBackdropStore extends BackdropStore {
  Backdrop? saved;

  @override
  Future<Backdrop> load() async => saved ?? Backdrop.standard;

  @override
  Future<void> save(Backdrop backdrop) async => saved = backdrop;
}

void main() {
  test('el fondo se guarda y se lee del celular', () async {
    final dir = await Directory.systemTemp.createTemp('fondo');
    addTearDown(() => dir.delete(recursive: true));
    final store = BackdropStore(directory: () async => dir);
    expect(await store.load(), Backdrop.clasico);
    await store.save(Backdrop.mostaza);
    expect(await store.load(), Backdrop.mostaza);
    expect(Backdrop.byName('no existe'), Backdrop.clasico);
    expect(Backdrop.clasico.gradient, isNotNull);
    expect(Backdrop.clasico.cards, CardStyle.sticker);
  });

  test('sin Todo Charadeando, el fondo Oro guardado se ve como el clásico', () {
    expect(Backdrop.oro.allowedWith(premium: false), Backdrop.clasico);
    expect(Backdrop.oro.allowedWith(premium: true), Backdrop.oro);
    expect(Backdrop.noche.allowedWith(premium: false), Backdrop.noche);
  });

  test('en los fondos claros los textos van oscuros', () {
    expect(Backdrop.crema.onColor, AppColors.ink);
    expect(Backdrop.mostaza.onColor, AppColors.ink);
    expect(Backdrop.noche.onColor, Colors.white);
    expect(Backdrop.noche.cards, CardStyle.sticker);
    final theme = buildAppTheme(Backdrop.crema);
    expect(theme.extension<BackdropTheme>()!.backdrop, Backdrop.crema);
    expect(theme.appBarTheme.foregroundColor, AppColors.ink);
  });

  testWidgets('al elegir un fondo cambia la app y queda guardado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final store = MemoryBackdropStore();
    final container = ProviderContainer(
      overrides: [backdropStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: Routes.backdrops,
      routes: [
        GoRoute(
          path: Routes.backdrops,
          builder: (_, _) => const BackdropScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            theme: buildAppTheme(ref.watch(backdropProvider)),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final b in Backdrop.values.where((b) => !b.premium)) {
      expect(find.text(b.label), findsOneWidget);
    }
    BoxDecoration background() => tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .first;
    // Viene elegido el clásico, con su degradado.
    expect(background().gradient, isNotNull);

    await tester.tap(find.text('Noche'));
    await tester.pumpAndSettle();
    expect(container.read(backdropProvider), Backdrop.noche);
    expect(store.saved, Backdrop.noche);
    expect(background().gradient, isNull);
    expect(background().color, Backdrop.noche.color);
  });

  Future<ProviderContainer> pumpBackdrops(
    WidgetTester tester, {
    required bool premium,
    MemoryBackdropStore? store,
  }) async {
    tester.view.physicalSize = const Size(1080, 3000);
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        backdropStoreProvider.overrideWithValue(store ?? MemoryBackdropStore()),
        premiumUnlockedProvider.overrideWithValue(premium),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: buildAppTheme(ref.watch(backdropProvider)),
            home: const BackdropScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('el fondo Oro no aparece hasta tener Todo Charadeando', (
    tester,
  ) async {
    await pumpBackdrops(tester, premium: false);
    expect(Backdrop.oro.premium, isTrue);
    expect(find.text('Turquesa'), findsOneWidget);
    expect(find.text('Oro', skipOffstage: false), findsNothing);
    expect(find.text('Exclusivo de Todo Charadeando'), findsNothing);
  });

  testWidgets('con Todo Charadeando aparece y se elige el fondo Oro, dorado '
      'y con brillo', (tester) async {
    final store = MemoryBackdropStore();
    final container = await pumpBackdrops(tester, premium: true, store: store);
    expect(find.text('Exclusivo de Todo Charadeando'), findsOneWidget);
    await tester.tap(find.text('Oro'));
    // El fondo Oro brilla sin parar: no se espera a que todo se detenga.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(backdropProvider), Backdrop.oro);
    expect(store.saved, Backdrop.oro);
    expect(Backdrop.oro.light, isTrue);
    expect(Backdrop.oro.shiny, isTrue);
    expect(find.byType(Shine), findsOneWidget);
  });
}
