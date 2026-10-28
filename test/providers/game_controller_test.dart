import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/services/services.dart';
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

  test('con palabras automáticas no se acaban antes del tiempo: vuelven '
      'las ya jugadas y se juegan todas las rondas', () {
    controller().configure(
      const GameConfig(
        rounds: 3,
        groups: [Group('A'), Group('B')],
        wordSource: WordSource.random,
        turnDuration: Duration(seconds: 30),
      ),
    );
    // Solo 8 palabras; un grupo rápido alcanza 10 en 30 segundos.
    controller().startWithWords(words('w', 8));
    expect(state().currentDeck, hasLength(4));
    play(hits: 4);
    // El grupo A se queda sin palabras propias y recibe las ya jugadas.
    expect(state().decks[0], isNotEmpty);
    play(hits: 4);
    for (var i = 0; i < 4; i++) {
      expect(state().finished, isFalse);
      play(hits: 2);
    }
    expect(state().finished, isTrue);
    expect(state().turns, hasLength(6));
  });

  test('en Fotomímica, con pocos objetos, las fotos se repiten y cada turno '
      'tiene las que alcanzaría un grupo rápido', () {
    controller().configure(
      const GameConfig(
        rounds: 5,
        groups: [Group('A'), Group('B')],
        wordSource: WordSource.random,
        category: GameCategory.photoMime,
        turnDuration: Duration(seconds: 30),
      ),
    );
    // Solo 6 objetos; un grupo rápido alcanza 10 en 30 segundos.
    final photos = [
      for (var i = 0; i < 6; i++)
        Word('Objeto $i', category: GameCategory.photoMime.code),
    ];
    controller().startWithWords(photos);
    for (final deck in state().decks) {
      expect(deck, hasLength(10));
      // Primero salen todos los objetos, sin repetir.
      expect(deck.take(6).toSet(), hasLength(6));
      // Nunca dos veces seguidas la misma foto.
      for (var i = 1; i < deck.length; i++) {
        expect(deck[i], isNot(deck[i - 1]));
      }
    }
    for (var turn = 0; turn < 10; turn++) {
      expect(state().finished, isFalse);
      expect(state().currentDeck, hasLength(10));
      play(hits: 7, passes: 3);
    }
    expect(state().finished, isTrue);
    expect(state().turns, hasLength(10));
  });

  test('Fotomímica permite como mucho 5 rondas; lo demás, 10', () {
    expect(
      const GameConfig(category: GameCategory.photoMime).roundsMax,
      GameConfig.maxPhotoMimeRounds,
    );
    expect(GameConfig.maxPhotoMimeRounds, 5);
    expect(const GameConfig().roundsMax, GameConfig.maxRounds);
  });

  group('estadísticas anónimas', () {
    late _RecordingStats stats;

    setUp(() {
      container.dispose();
      stats = _RecordingStats();
      container = ProviderContainer(
        overrides: [statsServiceProvider.overrideWithValue(stats)],
      );
      controller().configure(
        const GameConfig(rounds: 2, groups: [Group('A'), Group('B')]),
      );
      controller().setWrittenWords(0, words('a', 10));
      controller().setWrittenWords(1, words('b', 10));
      controller().start();
    });

    test('al terminar se registra una sola vez, como terminada', () {
      for (var i = 0; i < 4; i++) {
        play(hits: 2, passes: 1);
      }
      expect(state().finished, isTrue);
      controller()
        ..recordStats()
        ..recordStats();
      expect(stats.records, [(true, 4)]);
      // Jugar otra vez no la vuelve a registrar.
      controller().configure(state().config);
      expect(stats.records, hasLength(1));
    });

    test('si empiezan otra partida a la mitad, la anterior cuenta como '
        'abandonada', () {
      play(hits: 2);
      controller().configure(const GameConfig());
      expect(stats.records, [(false, 1)]);
    });

    test('sin ningún turno jugado no se registra nada', () {
      controller()
        ..recordStats()
        ..configure(const GameConfig());
      expect(stats.records, isEmpty);
    });
  });
}

/// Guarda qué se registró: (terminada, turnos).
class _RecordingStats extends NoStatsService {
  final records = <(bool, int)>[];

  @override
  Future<void> record({
    required GameConfig config,
    required List<Turn> turns,
    required bool finished,
    required PlayController controller,
    bool recordVideo = true,
  }) async => records.add((finished, turns.length));
}
