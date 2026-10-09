import 'dart:math';

import '../models/models.dart';

class WordService {
  WordService({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Arma el mazo de cada grupo con las palabras que escribió su rival:
  /// el grupo `i` escribe para el grupo `i + 1`, y el último para el primero.
  List<List<Word>> decksFromGroupWords(List<List<Word>> writtenByGroup) {
    final count = writtenByGroup.length;
    return List.generate(count, (target) {
      final author = (target - 1 + count) % count;
      return [...writtenByGroup[author]]..shuffle(_random);
    });
  }

  /// Índice del grupo que juega con las palabras que escribe [author].
  static int targetOf(int author, int groupCount) => (author + 1) % groupCount;
}
