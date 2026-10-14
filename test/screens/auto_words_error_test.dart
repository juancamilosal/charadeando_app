import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/auto_words_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Un banco de palabras cuyo servidor siempre falla con [status].
class _FailingBank extends WordBank {
  _FailingBank(this.status) : super(DirectusService());

  final int? status;

  @override
  Future<WordBatch> load(
    int count, {
    String? category,
    List<String>? categories,
    String? difficulty,
  }) async => throw DirectusException(status, 'error interno del servidor');
}

void main() {
  for (final (status, text) in [
    (500, 'Inténtalo otra vez en un momento.'),
    (404, 'Inténtalo otra vez en un momento.'),
    (null, 'Revisa tu conexión a internet e inténtalo otra vez.'),
  ]) {
    testWidgets('si no llegan las palabras ($status) solo dice que no se '
        'pudieron traer, sin detalles técnicos', (tester) async {
      final container = ProviderContainer(
        overrides: [wordBankProvider.overrideWithValue(_FailingBank(status))],
      );
      addTearDown(container.dispose);
      container
          .read(gameControllerProvider.notifier)
          .configure(
            const GameConfig(
              wordSource: WordSource.random,
              groups: [Group('')],
              inGroups: false,
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: Routes.autoWords,
              routes: [
                GoRoute(
                  path: Routes.autoWords,
                  builder: (_, _) => const AutoWordsScreen(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('No se pudieron traer las palabras'), findsOneWidget);
      expect(find.text(text), findsOneWidget);
      expect(find.textContaining('Directus'), findsNothing);
      expect(find.textContaining('servidor'), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  }
}
