import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'config_screen_test.dart' show pumpConfig, tapContinue;

void main() {
  const groups = [
    Group('Los Primos', teamId: 'p'),
    Group('Las Tías', teamId: 't'),
  ];

  test('la partida que sigue sumando empieza con los puntos que traían, '
      'pero el mejor puntaje del equipo es el de esa partida', () {
    final config = const GameConfig(
      groups: groups,
      rounds: 1,
    ).copyWith(startScores: [4, 8]);
    final game = GameState.fromConfig(config).copyWith(
      turns: [
        Turn(
          round: 1,
          groupIndex: 0,
          entries: [
            for (var i = 0; i < 6; i++) TurnEntry(Word('p$i'), WordOutcome.hit),
          ],
        ),
        Turn(
          round: 1,
          groupIndex: 1,
          entries: [TurnEntry(Word('t'), WordOutcome.hit)],
        ),
      ],
    );
    expect(game.scores, [10, 9]);
    expect(game.gameScores, [6, 1]);
    // Gana (y gira la ruleta) según el total.
    expect(game.leaders, [0]);
    expect(game.losers, [1]);
  });

  testWidgets('siguiendo la suma, la configuración muestra los mismos equipos '
      'con sus puntos y la partida empieza con ellos', (tester) async {
    final container = await pumpConfig(
      tester,
      config: const GameConfig(
        category: GameCategory.movies,
        wordSource: WordSource.random,
        inGroups: false,
      ),
      setUp: (c) =>
          c.read(scoreCarryProvider.notifier).keep(groups, const [4, 8]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Siguen sumando'), findsOneWidget);
    expect(find.text('8 pts'), findsOneWidget);
    expect(find.text('4 pts'), findsOneWidget);
    // No se cambian los equipos ni se juega sin equipos.
    expect(find.text('Sin equipos'), findsNothing);
    expect(find.text('Configuración aleatoria'), findsNothing);

    await tapContinue(tester);
    final config = container.read(gameControllerProvider).config;
    expect(config.inGroups, isTrue);
    expect([for (final g in config.groups) g.name], ['Los Primos', 'Las Tías']);
    expect(config.startScores, [4, 8]);
    expect(container.read(scoreCarryProvider), isNull);
  });

  testWidgets('"Empezar de cero" deja elegir como siempre', (tester) async {
    final container = await pumpConfig(
      tester,
      config: const GameConfig(
        category: GameCategory.movies,
        wordSource: WordSource.random,
      ),
      setUp: (c) =>
          c.read(scoreCarryProvider.notifier).keep(groups, const [4, 8]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empezar de cero'));
    await tester.pumpAndSettle();
    expect(container.read(scoreCarryProvider), isNull);
    expect(find.text('Siguen sumando'), findsNothing);
    expect(find.text('Configuración aleatoria'), findsOneWidget);
  });
}
