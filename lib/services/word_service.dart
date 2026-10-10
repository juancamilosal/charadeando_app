import 'dart:math';

import '../models/models.dart';

class WordService {
  WordService({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Arma el mazo de cada grupo con las palabras que escribieron los demás.
  /// Las palabras de cada grupo se reparten entre todos sus rivales, así que
  /// a nadie le salen las suyas, cada palabra se juega una sola vez y los
  /// mazos quedan de tamaños parecidos.
  List<List<Word>> decksFromGroupWords(List<List<Word>> writtenByGroup) {
    final count = writtenByGroup.length;
    final decks = List.generate(count, (_) => <Word>[]);
    for (var author = 0; author < count; author++) {
      final words = [...writtenByGroup[author]]..shuffle(_random);
      // Rivales en orden a partir del siguiente grupo, para repartir parejo.
      final rivals = [for (var i = 1; i < count; i++) (author + i) % count];
      for (var i = 0; i < words.length; i++) {
        decks[rivals[i % rivals.length]].add(words[i]);
      }
    }
    for (final deck in decks) {
      deck.shuffle(_random);
    }
    return decks;
  }

  /// Reparte las palabras automáticas entre los grupos, por turnos, para
  /// que los mazos queden del mismo tamaño.
  List<List<Word>> decksFromWords(List<Word> words, int groupCount) {
    final decks = List.generate(groupCount, (_) => <Word>[]);
    final shuffled = [...words]..shuffle(_random);
    for (var i = 0; i < shuffled.length; i++) {
      decks[i % groupCount].add(shuffled[i]);
    }
    return decks;
  }

  /// Cómo nombrar a los rivales de [author]: el nombre del grupo si solo hay
  /// uno, o "los demás grupos" si hay varios.
  static String rivalsLabel(int author, List<Group> groups) =>
      groups.length == 2 ? groups[(author + 1) % 2].name : 'los demás grupos';
}
