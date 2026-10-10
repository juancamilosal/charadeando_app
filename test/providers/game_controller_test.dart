import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

List<Word> words(String prefix, int count) => [
  for (var i = 0; i < count; i++) Word('$prefix$i'),
];

void main() {
  late ProviderContainer container;
  GameController controller() =>
      container.read(gameControllerProvider.notifier);
  GameState state() => container.read(gameControllerProvider);

  /// Juega el turno actual acertando [hits] palabras y pasando [passes].
  void play({int hits = 0, int passes = 0}) {
    final deck = state().currentDeck;
    controller().finishTurn(
      Turn(
        round: state().round,
        groupIndex: state().groupIndex,
        entries: [
          for (final w in deck.take(hits)) TurnEntry(w, WordOutcome.hit),
          for (final w in deck.skip(hits).take(passes))
            TurnEntry(w, WordOutcome.pass),
        ],
      ),
    );
    controller().advance();
  }

  setUp(() {
    container = ProviderContainer();
    controller().configure(
      const GameConfig(
        rounds: 2,
        groups: [Group('A'), Group('B')],
        scoringMode: ScoringMode.perPhrase,
      ),
    );
    controller().setWrittenWords(0, words('a', 10));
    controller().setWrittenWords(1, words('b', 10));
    controller().start();
  });

  tearDown(() => container.dispose());

  test('los grupos juegan por turnos y ronda tras ronda', () {
    expect((state().round, state().groupIndex), (1, 0));
    play(hits: 1);
    expect((state().round, state().groupIndex), (1, 1));
    play(hits: 1);
    expect((state().round, state().groupIndex), (2, 0));
    play(hits: 1);
    play(hits: 1);
    expect(state().finished, isTrue);
  });

  test('las palabras acertadas y pasadas no vuelven al mazo', () {
    final first = state().currentDeck.first;
    play(hits: 2, passes: 3);
    expect(state().decks[0], hasLength(5));
    expect(state().decks[0], isNot(contains(first)));
  });

  test('pasar no suma ni resta puntos', () {
    play(hits: 2, passes: 3);
    play(passes: 4);
    expect(state().scores, [2, 0]);
  });

  test('igualdad de puntos es empate, sin desempate', () {
    play(hits: 3);
    play(hits: 3);
    expect(state().isTie, isTrue);
    expect(state().leaders, [0, 1]);
  });

  test('salta a los grupos sin palabras y termina si no queda ninguna', () {
    play(hits: 10);
    expect(state().groupIndex, 1);
    play(hits: 10);
    expect(state().finished, isTrue);
    expect(state().leaders, [0, 1]);
  });

  test('un grupo sin palabras pierde su turno en las rondas siguientes', () {
    play(hits: 10);
    play(hits: 1);
    expect((state().round, state().groupIndex), (2, 1));
  });

  test('las palabras automáticas se reparten parejo entre los grupos', () {
    controller().startWithWords(words('w', 7));
    expect(state().decks.map((d) => d.length), [4, 3]);
    expect((state().round, state().groupIndex), (1, 0));
  });

  test('calcula cuántas palabras faltan y las agrega entre turnos', () {
    controller().startWithWords(words('w', 6));
    final deck = state().currentDeck;
    controller().finishTurn(
      Turn(
        round: 1,
        groupIndex: 0,
        entries: [for (final w in deck.take(2)) TurnEntry(w, WordOutcome.hit)],
      ),
    );
    // A: le queda 1 turno y 1 palabra; B: 2 turnos y 3 palabras, a 2 por turno.
    final needed = controller().wordsNeeded();
    expect(needed, [1, 1]);

    controller().addWords(words('x', 2), needed);
    expect(state().decks.map((d) => d.length), [2, 4]);
    expect(controller().wordsNeeded(), [0, 0]);
  });
}
