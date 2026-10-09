import 'game_config.dart';
import 'word.dart';

/// Resultado de una palabra dentro de un turno. Pasar no suma ni resta.
enum WordOutcome { hit, pass }

class TurnEntry {
  const TurnEntry(this.word, this.outcome);

  final Word word;
  final WordOutcome outcome;
}

/// Lo que ocurrió en el turno de un grupo durante una ronda.
class Turn {
  const Turn({
    required this.round,
    required this.groupIndex,
    required this.entries,
    this.videoPath,
  });

  final int round;
  final int groupIndex;

  /// Palabras en el orden en que salieron.
  final List<TurnEntry> entries;

  /// Video temporal del turno. Se borra al pasar al siguiente turno.
  final String? videoPath;

  List<Word> get hits => [
    for (final e in entries)
      if (e.outcome == WordOutcome.hit) e.word,
  ];

  List<Word> get passed => [
    for (final e in entries)
      if (e.outcome == WordOutcome.pass) e.word,
  ];

  int points(ScoringMode mode) =>
      hits.fold(0, (sum, word) => sum + mode.pointsFor(word.wordCount));

  Turn withoutVideo() =>
      Turn(round: round, groupIndex: groupIndex, entries: entries);
}
