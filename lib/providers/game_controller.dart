import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/error_reporter.dart';
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
    this.historySaved = false,
    this.statsSent = false,
    this.errorsAtStart = 0,
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

  /// Ya se sumó esta partida al historial de los equipos guardados.
  final bool historySaved;

  /// Ya se registraron sus estadísticas anónimas.
  final bool statsSent;

  /// Errores reportados en la app cuando empezó la partida
  /// ([ErrorReporter.errorCount]), para saber si hubo alguno durante ella.
  final int errorsAtStart;

  List<Group> get groups => config.groups;
  Group get currentGroup => groups[groupIndex];
  List<Word> get currentDeck => decks[groupIndex];

  Turn? get lastTurn => turns.isEmpty ? null : turns.last;

  /// Se juega en grupos. Sin grupos hay un único grupo sin nombre y no hay
  /// ganador.
  bool get inGroups => config.inGroups;

  /// "Turno de Los Tigres", o "¡A jugar!" sin grupos.
  String get turnTitle =>
      inGroups ? 'Turno de ${currentGroup.name}' : '¡A jugar!';

  /// Puntos de toda la partida, sumando los de todos los grupos.
  int get totalScore => scores.fold(0, (a, b) => a + b);

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
    bool? historySaved,
    bool? statsSent,
    int? errorsAtStart,
  }) {
    return GameState(
      config: config,
      writtenWords: writtenWords ?? this.writtenWords,
      decks: decks ?? this.decks,
      turns: turns ?? this.turns,
      round: round ?? this.round,
      groupIndex: groupIndex ?? this.groupIndex,
      finished: finished ?? this.finished,
      historySaved: historySaved ?? this.historySaved,
      statsSent: statsSent ?? this.statsSent,
      errorsAtStart: errorsAtStart ?? this.errorsAtStart,
    );
  }
}

class GameController extends Notifier<GameState> {
  final _random = Random();

  @override
  GameState build() => GameState.fromConfig(const GameConfig());

  /// Empieza a preparar una partida nueva con [config]. Si la anterior se
  /// quedó a la mitad, se registra como abandonada.
  void configure(GameConfig config) {
    recordStats();
    state = GameState.fromConfig(config);
  }

  /// Registra las estadísticas anónimas de la partida, una sola vez y solo
  /// si se jugó al menos un turno: terminada si llegó al resultado final (o
  /// es una partida rápida, que termina con su único turno), abandonada si
  /// no. Se envía por detrás y nunca demora el juego.
  void recordStats() {
    final game = state;
    if (game.turns.isEmpty || game.statsSent) return;
    state = game.copyWith(statsSent: true);
    ref
        .read(statsServiceProvider)
        .record(
          config: game.config,
          turns: game.turns,
          finished: game.finished || game.config.quick,
          controller: ref.read(settingsProvider).controller,
        )
        .ignore();
  }

  /// Si hubo algún error en la app desde que empezó la partida.
  bool get hadErrors => ErrorReporter.instance.errorCount > state.errorsAtStart;

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
  /// En Fotomímica, si no alcanzan los objetos, cada mazo se completa
  /// repitiendo fotos.
  void startWithWords(List<Word> words) {
    final decks = ref
        .read(wordServiceProvider)
        .decksFromWords(words, state.groups.length);
    startWithDecks(
      state.config.photoMime
          ? [
              for (final deck in decks)
                _repeatPhotos(deck, words, state.config.fastWordsPerTurn),
            ]
          : decks,
    );
  }

  void startWithDecks(List<List<Word>> decks) {
    final config = state.config;
    final reporter = ErrorReporter.instance
      ..setKey(CrashKeys.gameMode, switch (config) {
        GameConfig(hitMode: HitMode.tv) => 'tv',
        GameConfig(judgePhone: true) => 'juez',
        GameConfig(photoMime: true) => 'fotomimica',
        _ => 'normal',
      })
      ..setKey(CrashKeys.resolution, config.resolution.name);
    state = _firstPlayableFrom(
      state.copyWith(
        decks: decks,
        turns: const [],
        round: 1,
        groupIndex: 0,
        errorsAtStart: reporter.errorCount,
      ),
    );
  }

  /// Registra el turno recién jugado y saca sus palabras del mazo.
  /// Con palabras automáticas, si al grupo le quedan pocas, se completan
  /// con palabras ya jugadas.
  void finishTurn(Turn turn) {
    var deck = [...state.decks[turn.groupIndex]];
    for (final entry in turn.entries) {
      deck.remove(entry.word);
    }
    if (state.config.untilTimeRunsOut) {
      deck = _refill(deck, turn);
    }
    final decks = [...state.decks];
    decks[turn.groupIndex] = deck;
    state = state.copyWith(decks: decks, turns: [...state.turns, turn]);
  }

  /// Corrige una palabra del último turno (se marcó mal): la [index] queda
  /// como [outcome] y los puntos se recalculan solos.
  void correctLastTurn(int index, WordOutcome outcome) {
    final turn = state.lastTurn;
    if (turn == null || index < 0 || index >= turn.entries.length) return;
    final entries = [...turn.entries];
    if (entries[index].outcome == outcome) return;
    entries[index] = TurnEntry(entries[index].word, outcome);
    state = state.copyWith(
      turns: [
        ...state.turns.sublist(0, state.turns.length - 1),
        Turn(
          round: turn.round,
          groupIndex: turn.groupIndex,
          entries: List.unmodifiable(entries),
        ),
      ],
    );
  }

  /// Termina la partida antes de tiempo ("Finalizar juego"): cuentan los
  /// turnos jugados hasta ahora.
  void endGame() {
    state = state.copyWith(finished: true);
  }

  /// Al terminar la partida, la suma una sola vez al historial de los
  /// equipos guardados.
  Future<void> saveHistory() async {
    if (state.historySaved || !state.finished) return;
    final game = state;
    state = state.copyWith(historySaved: true);
    await ref.read(teamsProvider.notifier).recordGame(game);
  }

  /// Con palabras automáticas el turno dura hasta que se acabe el tiempo: si al
  /// grupo le quedan menos palabras de las que alcanzaría un grupo rápido,
  /// se completan con palabras ya jugadas, al azar.
  List<Word> _refill(List<Word> deck, Turn justPlayed) {
    final need = state.config.fastWordsPerTurn - deck.length;
    if (need <= 0) return deck;
    if (state.config.photoMime) {
      // Hay pocos objetos: se repiten, mejor los que este grupo no acaba
      // de ver.
      return _repeatPhotos(
        deck,
        {
          for (final d in state.decks) ...d,
          for (final t in [...state.turns, justPlayed])
            for (final e in t.entries) e.word,
        },
        state.config.fastWordsPerTurn,
        avoid: {for (final e in justPlayed.entries) e.word},
      );
    }
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

  /// Fotomímica: completa [deck] hasta [size] fotos con las de [pool],
  /// aunque se repitan, porque todavía hay pocos objetos. Primero van las
  /// que no están en el mazo ni en [avoid]; después, las que no están en el
  /// mazo, y si aun así faltan, cualquiera que no sea igual a la anterior.
  List<Word> _repeatPhotos(
    List<Word> deck,
    Iterable<Word> pool,
    int size, {
    Set<Word> avoid = const {},
  }) {
    final photos = pool.toSet().toList();
    if (photos.isEmpty) return deck;
    final result = [...deck];
    while (result.length < size) {
      final fresh = [
        for (final p in photos)
          if (!result.contains(p) && !avoid.contains(p)) p,
      ];
      final unused = [
        for (final p in photos)
          if (!result.contains(p)) p,
      ];
      final other = [
        for (final p in photos)
          if (p != result.lastOrNull) p,
      ];
      final options = fresh.isNotEmpty
          ? fresh
          : unused.isNotEmpty
          ? unused
          : other.isNotEmpty
          ? other
          : photos;
      result.add(options[_random.nextInt(options.length)]);
    }
    return result;
  }

  /// Pasa al siguiente grupo, o a la siguiente ronda cuando ya jugaron todos.
  void advance() => state = afterAdvance;

  /// Cómo queda la partida al pasar al siguiente turno, sin pasar todavía:
  /// para que el botón diga a quién le toca o si ya terminó.
  GameState get afterAdvance {
    final next = state.groupIndex + 1;
    return _firstPlayableFrom(
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
