import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/punishments.dart';
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

  /// Palabras del turno que va a jugar el grupo actual. Con palabras
  /// automáticas, cada turno tiene su propio mazo: las primeras
  /// [GameConfig.wordsPerTurn] del grupo.
  List<Word> get currentTurnWords => config.perTurnDecks
      ? currentDeck.take(config.wordsPerTurn).toList()
      : currentDeck;
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

  /// Índices de los grupos que giran la ruleta de castigos: los de menos
  /// puntos. Vacío si todos empatan.
  List<int> get losers => Roulette.losers(scores);

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
  final _random = Random();

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
  /// Con palabras automáticas, las palabras del turno que no alcanzaron a
  /// salir se descartan: el siguiente turno trae palabras nuevas.
  void finishTurn(Turn turn) {
    var deck = [...state.decks[turn.groupIndex]];
    if (state.config.perTurnDecks) {
      deck = deck.skip(state.config.wordsPerTurn).toList();
    } else {
      for (final entry in turn.entries) {
        deck.remove(entry.word);
      }
      if (state.config.untilTimeRunsOut) {
        deck = _refill(deck, turn);
      }
    }
    final decks = [...state.decks];
    decks[turn.groupIndex] = deck;
    state = state.copyWith(decks: decks, turns: [...state.turns, turn]);
  }

  /// Termina la partida antes de tiempo ("Finalizar juego"): cuentan los
  /// turnos jugados hasta ahora.
  void endGame() {
    state = state.copyWith(finished: true);
  }

  /// Por número de rondas el turno dura hasta que se acabe el tiempo: si al
  /// grupo le quedan menos palabras de las que alcanzaría un grupo rápido,
  /// se completan con palabras ya jugadas, al azar.
  List<Word> _refill(List<Word> deck, Turn justPlayed) {
    final need = state.config.maxWordsPerTurnByTime - deck.length;
    if (need <= 0) return deck;
    // Las que siguen en algún mazo no se repiten; el del grupo que acaba de
    // jugar es [deck], porque el estado todavía tiene el anterior.
    final inDecks = {
      for (var g = 0; g < state.decks.length; g++)
        if (g != justPlayed.groupIndex) ...state.decks[g],
      ...deck,
    };
    final played = <Word>{
      for (final t in [...state.turns, justPlayed])
        for (final e in t.entries)
          if (!inDecks.contains(e.word)) e.word,
    }.toList()..shuffle(_random);
    return [...deck, ...played.take(need)];
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
    if (from.decks.every((d) => d.isEmpty)) {
      return from.copyWith(finished: true);
    }
    final limit = from.config.roundLimit;
    var round = from.round;
    var group = from.groupIndex;
    while (round <= limit) {
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
