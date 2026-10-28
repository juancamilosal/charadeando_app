import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/turn_result_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../providers/my_videos_test.dart' show FakeGallery, MemoryVideosStore;
import '../services/settings_test.dart' show MemorySettingsStore;

/// El video del turno ya está listo, sin guardar. No borra nada de verdad.
class _ReadyVideo extends TurnVideoController {
  @override
  TurnVideoState build() =>
      const TurnVideoState(TurnVideoStatus.ready, path: '/tmp/turno.mp4');

  @override
  Future<void> discard() async => state = TurnVideoState.none;
}

Future<(ProviderContainer, MemoryVideosStore)> _pump(
  WidgetTester tester, {
  bool autoSave = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);
  final store = MemoryVideosStore();
  final container = ProviderContainer(
    overrides: [
      tvConnectedProvider.overrideWith((ref) => Stream.value(false)),
      turnVideoProvider.overrideWith(_ReadyVideo.new),
      videoGalleryProvider.overrideWithValue(FakeGallery()),
      myVideosStoreProvider.overrideWithValue(store),
      settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      settingsProvider.overrideWith(
        () => SettingsController(AppSettings(autoSaveVideo: autoSave)),
      ),
    ],
  );
  addTearDown(container.dispose);
  final game = container.read(gameControllerProvider.notifier);
  game.configure(
    QuickGame.config(
      const GameConfig(
        category: GameCategory.animals,
        wordSource: WordSource.random,
      ),
    ),
  );
  game.startWithWords([Word('León')]);
  game.finishTurn(
    Turn(
      round: 1,
      groupIndex: 0,
      entries: [TurnEntry(Word('León'), WordOutcome.hit)],
    ),
  );
  final router = GoRouter(
    initialLocation: Routes.turnResult,
    routes: [
      GoRoute(
        path: Routes.turnResult,
        builder: (_, _) => const TurnResultScreen(),
      ),
      GoRoute(
        path: Routes.categories,
        builder: (_, _) => const Text('Categorías'),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  return (container, store);
}

Future<void> _tapExit(WidgetTester tester) async {
  final exit = find.text('Salir de la categoría');
  await tester.ensureVisible(exit);
  await tester.pump();
  await tester.tap(exit);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('"Guardar" junto a "Ver video" lo guarda en Mis videos', (
    tester,
  ) async {
    final (_, store) = await _pump(tester);
    expect(
      find.text('Guárdalo para verlo en Mis videos. Si no, se borra al salir.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(store.videos, hasLength(1));
    expect(find.text('Guardado'), findsOneWidget);
    expect(find.text('Guardado en Mis videos.'), findsOneWidget);

    // Ya guardado, sale sin preguntar (cuando se va el aviso).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tapExit(tester);
    expect(find.text('Categorías'), findsOneWidget);
  });

  testWidgets('al salir sin guardar pregunta: "Guardar" lo guarda y sale', (
    tester,
  ) async {
    final (_, store) = await _pump(tester);
    await _tapExit(tester);
    expect(find.text('¿Salir sin guardar el video?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar').last);
    await tester.pumpAndSettle();
    expect(store.videos, hasLength(1));
    expect(find.text('Categorías'), findsOneWidget);
  });

  testWidgets('"Salir sin guardar" sale sin guardarlo', (tester) async {
    final (_, store) = await _pump(tester);
    await _tapExit(tester);
    await tester.tap(find.text('Salir sin guardar'));
    await tester.pumpAndSettle();
    expect(store.videos, isEmpty);
    expect(find.text('Categorías'), findsOneWidget);
  });

  testWidgets('con "Guardar automáticamente" no pregunta al salir', (
    tester,
  ) async {
    await _pump(tester, autoSave: true);
    expect(find.text('Se guarda solo en Mis videos.'), findsOneWidget);
    await _tapExit(tester);
    expect(find.text('¿Salir sin guardar el video?'), findsNothing);
    expect(find.text('Categorías'), findsOneWidget);
  });
}
