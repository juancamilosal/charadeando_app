/// Reglas de las palabras del juego "Letras": cómo se comparan, si
/// empiezan con la letra y si ya se dijeron.
abstract final class LetterWords {
  /// Letras con que se puede jugar, en orden. La Ñ es una letra aparte.
  static const alphabet = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', //
    'Ñ', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  /// Letras difíciles: casi no hay palabras que empiecen con ellas.
  static const hardLetters = {'Ñ', 'Q', 'W', 'X', 'Y', 'K', 'Z'};

  /// Letras del nivel Fácil: todas menos [hardLetters].
  static List<String> get easyLetters => [
    for (final l in alphabet)
      if (!hardLetters.contains(l)) l,
  ];

  static const _plain = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', //
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  };

  /// La palabra para compararla: en minúsculas, sin tildes ni diéresis y
  /// sin lo que no sea letra. La ñ se conserva ("año" no es "ano").
  /// Es la misma clave del diccionario (`tool/diccionario/construir.py`).
  static String key(String word) {
    final buffer = StringBuffer();
    for (final rune in word.toLowerCase().runes) {
      final c = String.fromCharCode(rune);
      final plain = _plain[c] ?? c;
      if (_isLetter(plain)) buffer.write(plain);
    }
    return buffer.toString();
  }

  static bool _isLetter(String c) =>
      c == 'ñ' || (c.codeUnitAt(0) >= 0x61 && c.codeUnitAt(0) <= 0x7a);

  /// La clave para saber si ya se dijo: como [key], y sin la "s" final,
  /// así "casa" y "casas" cuentan como la misma.
  static String repeatKey(String word) {
    final k = key(word);
    return k.length > 1 && k.endsWith('s') ? k.substring(0, k.length - 1) : k;
  }

  /// Si [word] empieza con [letter] ("Árbol" empieza con la A; "ñandú",
  /// con la Ñ y no con la N).
  static bool startsWith(String word, String letter) {
    final k = key(word);
    return k.isNotEmpty && k[0] == key(letter);
  }

  /// Las palabras de lo que entendió el reconocimiento de voz ("casa
  /// grande" son dos). Quita números, signos y lo que no tenga letras.
  static List<String> split(String text) => [
    for (final part in text.split(RegExp(r'[\s,.;:!?¡¿"()]+')))
      if (key(part).isNotEmpty && !RegExp(r'\d').hasMatch(part)) part.trim(),
  ];
}

/// Por qué una palabra vale o no.
enum WordVerdict {
  valid('✓ válida'),
  wrongLetter('❌ no empieza con la letra'),
  repeated('❌ repetida'),
  notInDictionary('❌ no está en el diccionario');

  const WordVerdict(this.label);

  final String label;
}

/// Revisa las palabras de una ronda con la letra [letter]: que empiecen con
/// ella, que estén en el diccionario ([inDictionary]) y que nadie las haya
/// dicho antes en la ronda.
class WordChecker {
  WordChecker(this.letter, {required this.inDictionary});

  final String letter;
  final bool Function(String word) inDictionary;
  final _said = <String>{};

  /// Las palabras válidas, sin repetir.
  int get validCount => _said.length;

  /// Revisa [word] y, si vale, la anota como dicha.
  WordVerdict check(String word) {
    if (!LetterWords.startsWith(word, letter)) return WordVerdict.wrongLetter;
    final repeat = LetterWords.repeatKey(word);
    if (_said.contains(repeat)) return WordVerdict.repeated;
    if (!inDictionary(word)) return WordVerdict.notInDictionary;
    _said.add(repeat);
    return WordVerdict.valid;
  }

  /// Quita una palabra que se había aceptado (se entendió mal).
  void remove(String word) => _said.remove(LetterWords.repeatKey(word));

  void reset() => _said.clear();
}
