import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'providers.dart';

class GameState {
  const GameState({
    required this.config,
    required this.writtenWords,
    this.decks = const [],
    this.turns = const [],
    this.round = 1,
    this.groupIndex = 0,
    this.finished = false,
  });

  factory GameState.fromConfig(GameConfig config) => GameState(
    config: config,
    writtenWords: List.generate(config.groupCount, (_) => const []),
  );

  final GameConfig config;

  /// Palabras escritas por cada grupo para su rival, por índice de autor.
  final List<List<Word>> writtenWords;

  /// Palabras que le quedan por jugar a cada grupo. Las que se aciertan o
  /// se pasan salen del mazo y no vuelven.
  final List<List<Word>> decks;

  final List<Turn> turns;

  /// Ronda actual, empezando en 1.
  final int round;

  /// Grupo al que le toca jugar.
  final int groupIndex;
  final bool finished;

  List<Group> get groups => config.groups;
  Group get currentGroup => groups[groupIndex];
  List<Word> get currentDeck => decks[groupIndex];
  Turn? get lastTurn => turns.isEmpty ? null : turns.last;

  List<int> get scores {
    final scores = List.filled(groups.length, 0);
    for (final turn in turns) {
      scores[turn.groupIndex] += turn.points(config.scoringMode);
    }
    return scores;
  }

  /// Índices de los grupos con el puntaje más alto. Más de uno es empate.
  List<int> get leaders {
    final scores = this.scores;
    final best = scores.reduce((a, b) => a > b ? a : b);
    return [
      for (var i = 0; i < scores.length; i++)
        if (scores[i] == best) i,
    ];
  }

  bool get isTie => leaders.length > 1;

  GameState copyWith({
    List<List<Word>>? writtenWords,
    List<List<Word>>? decks,
    List<Turn>? turns,
    int? round,
    int? groupIndex,
    bool? finished,
  }) {
    return GameState(
      config: config,
      writtenWords: writtenWords ?? this.writtenWords,
      decks: decks ?? this.decks,
      turns: turns ?? this.turns,
      round: round ?? this.round,
      groupIndex: groupIndex ?? this.groupIndex,
      finished: finished ?? this.finished,
    );
  }
}

class GameController extends Notifier<GameState> {
  @override
  GameState build() => GameState.fromConfig(const GameConfig());

  /// Empieza a preparar una partida nueva con [config].
  void configure(GameConfig config) {
    state = GameState.fromConfig(config);
  }

  void setWrittenWords(int author, List<Word> words) {
    final written = [...state.writtenWords];
    written[author] = List.unmodifiable(words);
    state = state.copyWith(writtenWords: written);
  }

  /// Empieza con las palabras que escribieron los grupos.
  void start() => startWithDecks(
    ref.read(wordServiceProvider).decksFromGroupWords(state.writtenWords),
  );

  /// Empieza con las palabras automáticas, repartidas entre los grupos.
  void startWithWords(List<Word> words) => startWithDecks(
    ref.read(wordServiceProvider).decksFromWords(words, state.groups.length),
  );

  void startWithDecks(List<List<Word>> decks) {
    state = _firstPlayableFrom(
      state.copyWith(decks: decks, turns: const [], round: 1, groupIndex: 0),
    );
  }

  /// Registra el turno recién jugado y saca sus palabras del mazo.
  void finishTurn(Turn turn) {
    final deck = [...state.decks[turn.groupIndex]];
    for (final entry in turn.entries) {
      deck.remove(entry.word);
    }
    final decks = [...state.decks];
    decks[turn.groupIndex] = deck;
    state = state.copyWith(decks: decks, turns: [...state.turns, turn]);
  }

  /// Palabras que le faltarían a cada grupo para sus turnos restantes,
  /// calculando con el turno en que más palabras se usaron. Sirve para
  /// pedir más palabras automáticas entre turnos.
  List<int> wordsNeeded() {
    if (state.turns.isEmpty) return List.filled(state.groups.length, 0);
    final perTurn = state.turns
        .map((t) => t.entries.length)
        .reduce((a, b) => a > b ? a : b);
    final needed = <int>[];
    for (var g = 0; g < state.groups.length; g++) {
      final turnsLeft =
          state.config.rounds - state.round + (g > state.groupIndex ? 1 : 0);
      final missing = turnsLeft * perTurn - state.decks[g].length;
      needed.add(missing > 0 ? missing : 0);
    }
    return needed;
  }

  /// Agrega [words] a los mazos, llenando primero lo que le falta a cada
  /// grupo según [needed].
  void addWords(List<Word> words, List<int> needed) {
    final decks = [
      for (final d in state.decks) [...d],
    ];
    var next = 0;
    for (var g = 0; g < decks.length && next < words.length; g++) {
      for (var i = 0; i < needed[g] && next < words.length; i++) {
        decks[g].add(words[next++]);
      }
    }
    state = state.copyWith(decks: decks);
  }

  /// Pasa al siguiente grupo, o a la siguiente ronda cuando ya jugaron todos.
  void advance() {
    final next = state.groupIndex + 1;
    state = _firstPlayableFrom(
      next < state.groups.length
          ? state.copyWith(groupIndex: next)
          : state.copyWith(round: state.round + 1, groupIndex: 0),
    );
  }

  /// Desde la posición de [from], busca el primer turno de un grupo al que
  /// le queden palabras. Si no hay ninguno, la partida termina.
  GameState _firstPlayableFrom(GameState from) {
    var round = from.round;
    var group = from.groupIndex;
    while (round <= from.config.rounds) {
      if (from.decks[group].isNotEmpty) {
        return from.copyWith(round: round, groupIndex: group, finished: false);
      }
      group++;
      if (group == from.groups.length) {
        group = 0;
        round++;
      }
    }
    return from.copyWith(finished: true);
  }
}
