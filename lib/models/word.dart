/// Una palabra o frase que el jugador debe adivinar.
class Word {
  Word(
    String text, {
    this.category,
    this.id,
    this.image,
    this.answer,
    this.topic,
    this.note,
    this.value,
  }) : text = _normalize(text);

  final String text;
  final String? category;

  /// Id en Directus de las palabras automáticas. No cuenta para comparar
  /// palabras.
  final String? id;

  /// En Fotomímica, la foto del objeto ya descargada en el celular (ruta
  /// del archivo). En el turno se muestra la foto y el texto, pequeño,
  /// debajo. Null en las palabras.
  final String? image;

  /// En "¿Más o menos?", [text] es la pregunta y esta la respuesta ya
  /// escrita con su unidad ("8 patas", "1969"). Null en las palabras.
  final String? answer;

  /// En "¿Más o menos?", el tema del dato ("Animales"), que va arriba de la
  /// pregunta.
  final String? topic;

  /// En "¿Más o menos?", el dato curioso que se ve en el resultado del
  /// turno.
  final String? note;

  /// Puntos fijos que da al acertarla, sin importar la puntuación elegida.
  /// En "¿Más o menos?" depende de la dificultad del dato (1, 2 o 5); null
  /// en las palabras, que se cuentan por frase o por palabra.
  final int? value;

  /// Es un dato de "¿Más o menos?" (pregunta y respuesta).
  bool get isFact => answer != null;

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
