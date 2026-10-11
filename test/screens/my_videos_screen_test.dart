import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/my_videos_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../providers/my_videos_test.dart';

Future<void> _pump(
  WidgetTester tester,
  MemoryVideosStore store,
  FakeGallery gallery,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Routes.myVideos,
    routes: [
      GoRoute(path: Routes.myVideos, builder: (_, _) => const MyVideosScreen()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myVideosStoreProvider.overrideWithValue(store),
        videoGalleryProvider.overrideWithValue(gallery),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('la fecha se escribe en español', () {
    expect(
      formatVideoDate(DateTime(2026, 10, 11, 21, 41)),
      '11 oct 2026 · 9:41 p. m.',
    );
    expect(
      formatVideoDate(DateTime(2026, 1, 2, 0, 5)),
      '2 ene 2026 · 12:05 a. m.',
    );
  });

  testWidgets('sin videos explica cómo guardarlos y aclara la privacidad', (
    tester,
  ) async {
    await _pump(tester, MemoryVideosStore(), FakeGallery());
    expect(find.text('Todavía no hay videos'), findsOneWidget);
    expect(
      find.text(
        'Tus videos se guardan solo en este celular. No los subimos a '
        'ningún lado.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('muestra los videos y al borrar pregunta por la galería', (
    tester,
  ) async {
    final store = MemoryVideosStore([
      video('a', 1),
      video('b', 2, group: null),
    ]);
    final gallery = FakeGallery(ids: {'a', 'b'});
    await _pump(tester, store, gallery);

    expect(find.text('Los Tigres · +5 puntos'), findsOneWidget);
    expect(find.text('+5 puntos'), findsOneWidget);
    expect(find.text('Animales · Ronda 2'), findsNWidgets(2));
    // El más nuevo va primero.
    expect(
      tester.getTopLeft(find.text('+5 puntos')).dy,
      lessThan(tester.getTopLeft(find.text('Los Tigres · +5 puntos')).dy),
    );

    await tester.tap(find.byTooltip('Borrar').last);
    await tester.pumpAndSettle();
    expect(find.text('¿Borrarlo también de la galería?'), findsOneWidget);
    await tester.tap(find.text('También de la galería'));
    await tester.pumpAndSettle();
    expect(find.text('Los Tigres · +5 puntos'), findsNothing);
    expect(gallery.ids, {'b'});

    await tester.tap(find.byTooltip('Borrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solo de Mis videos'));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no hay videos'), findsOneWidget);
    expect(gallery.ids, {'b'});
  });

  testWidgets('con acceso limitado avisa que pueden faltar videos', (
    tester,
  ) async {
    await _pump(
      tester,
      MemoryVideosStore(),
      FakeGallery(mode: GalleryAccess.limited),
    );
    expect(find.text('Elegir videos'), findsOneWidget);
  });
}
