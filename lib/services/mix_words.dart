import 'dart:math';

import '../models/models.dart';

/// Reparte las palabras de una partida con varias categorías
/// ("Combinar categorías").
abstract final class MixWords {
  /// Cuántas palabras le tocan a cada una de [parts] categorías para
  /// juntar [total], en partes iguales. El sobrante se reparte de a una
  /// entre las primeras: 46 en 3 son 16, 15 y 15.
  static List<int> quotas(int total, int parts) {
    if (parts <= 0) return const [];
    final base = total ~/ parts;
    final extra = total % parts;
    return [for (var i = 0; i < parts; i++) base + (i < extra ? 1 : 0)];
  }

  /// Junta [total] palabras de [sources] (una lista por categoría, en el
  /// orden de la partida), en partes iguales. Si una categoría no alcanza,
  /// lo que falta se completa, de a una, con las sobrantes de las otras.
  /// Al final se barajan juntas.
  static List<Word> combine(
    List<List<Word>> sources, {
    required int total,
    Random? random,
  }) {
    final rnd = random ?? Random();
    final pools = [
      for (final s in sources) [...s]..shuffle(rnd),
    ];
    final quota = quotas(total, pools.length);
    final taken = <Word>[];
    final seen = <Word>{};
    var missing = 0;
    for (var i = 0; i < pools.length; i++) {
      var count = 0;
      while (count < quota[i] && pools[i].isNotEmpty) {
        if (seen.add(pools[i].first)) {
          taken.add(pools[i].first);
          count++;
        }
        pools[i].removeAt(0);
      }
      missing += quota[i] - count;
    }
    // Completa con las que sobraron, turnándose entre las categorías.
    while (missing > 0 && pools.any((p) => p.isNotEmpty)) {
      for (final pool in pools) {
        if (missing == 0) break;
        while (pool.isNotEmpty) {
          final word = pool.removeAt(0);
          if (seen.add(word)) {
            taken.add(word);
            missing--;
            break;
          }
        }
      }
    }
    return taken..shuffle(rnd);
  }

  /// Las palabras de [category] para una mezcla: conservan su categoría
  /// para mostrarla arriba de la palabra durante el turno.
  static List<Word> customWords(CustomCategory category) => [
    for (final w in category.words)
      Word(w, category: '${GameConfig.customWordPrefix}${category.id}'),
  ];

  /// Cuántas palabras pedirle a Directus para que, junto con las propias,
  /// se junten [total]: su parte en el reparto más lo que les falte a las
  /// propias que no alcancen.
  static int remoteCount(
    int total, {
    required int gameCategories,
    required List<int> customSizes,
  }) {
    if (gameCategories == 0) return 0;
    final quota = quotas(total, gameCategories + customSizes.length);
    var count = 0;
    for (var i = 0; i < gameCategories; i++) {
      count += quota[i];
    }
    for (var i = 0; i < customSizes.length; i++) {
      count += max(0, quota[gameCategories + i] - customSizes[i]);
    }
    return count;
  }
}
