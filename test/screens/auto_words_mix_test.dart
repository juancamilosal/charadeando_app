import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/auto_words_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('con solo categorías propias se juega sin internet y cada '
      'palabra conserva su categoría', (tester) async {
    final family = CustomCategory(
      id: 'f1',
      name: 'Mi familia',
      words: [for (var i = 0; i < 12; i++) 'Primo $i'],
    );
    final office = CustomCategory(
      id: 'o1',
      name: 'La oficina',
      words: [for (var i = 0; i < 12; i++) 'Jefe $i'],
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(gameControllerProvider.notifier)
        .configure(
          GameConfig(
            wordSource: WordSource.random,
            rounds: 1,
            turnDuration: const Duration(seconds: 30),
            groups: const [Group('')],
            inGroups: false,
            mixCustom: [family, office],
          ),
        );
    final router = GoRouter(
      initialLocation: Routes.autoWords,
      routes: [
        GoRoute(
          path: Routes.autoWords,
          builder: (_, _) => const AutoWordsScreen(),
        ),
        GoRoute(path: Routes.turn, builder: (_, _) => const Text('Turno')),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Turno'), findsOneWidget);

    final game = container.read(gameControllerProvider);
    final deck = game.decks.single;
    // 30 s por turno: 10 palabras, 5 de cada categoría.
    expect(deck, hasLength(10));
    expect(deck.where((w) => w.category == 'mia:f1'), hasLength(5));
    expect(deck.where((w) => w.category == 'mia:o1'), hasLength(5));
    expect(game.config.wordCategoryLabel(deck.first), isNotNull);
  });
}
