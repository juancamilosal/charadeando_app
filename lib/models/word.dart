/// Una palabra o frase que el jugador debe adivinar.
class Word {
  Word(String text, {this.category}) : text = _normalize(text);

  final String text;
  final String? category;

  /// Cantidad de palabras de la frase. Cuentan también artículos y
  /// conectores: "El Rey León" tiene 3.
  int get wordCount => text.isEmpty ? 0 : text.split(' ').length;

  static String _normalize(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ');

  @override
  bool operator ==(Object other) =>
      other is Word && other.text == text && other.category == category;

  @override
  int get hashCode => Object.hash(text, category);

  @override
  String toString() => 'Word($text)';
}
