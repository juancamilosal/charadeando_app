/// Un dato de "¿Más o menos?" en Directus (colección `datos`): una
/// pregunta y su respuesta, un número entero exacto.
class FactItem {
  const FactItem({
    required this.id,
    required this.question,
    required this.answer,
    this.unit,
    this.note,
    this.topic,
    this.difficulty,
  });

  /// Lee un dato de la respuesta de `/juego/datos`
  /// (`{ id, pregunta, respuesta, unidad, dato_curioso, categoria,
  /// dificultad }`). Null si le falta la pregunta o la respuesta no es un
  /// número entero.
  static FactItem? fromJson(Map<String, dynamic> json) {
    final question = '${json['pregunta'] ?? ''}'.trim();
    final answer = json['respuesta'];
    if (question.isEmpty || answer is! int) return null;
    String? text(Object? v) {
      final t = v is String ? v.trim() : '';
      return t.isEmpty ? null : t;
    }

    return FactItem(
      id: '${json['id'] ?? ''}',
      question: question,
      answer: answer,
      unit: text(json['unidad']),
      note: text(json['dato_curioso']),
      topic: text(json['categoria']),
      difficulty: text(json['dificultad']),
    );
  }

  final String id;
  final String question;
  final int answer;

  /// Va después del número: "patas" en "8 patas". Null en los años.
  final String? unit;

  /// El dato curioso.
  final String? note;

  /// Tema del dato ("Animales").
  final String? topic;

  /// `FACIL`, `NORMAL` o `DIFICIL`.
  final String? difficulty;

  /// La respuesta para leerla de lejos: "8 patas", "1969", "42.195
  /// metros". Los números de 5 cifras o más llevan puntos de miles; los
  /// de 4 (como los años) no.
  String get answerText {
    final number = formatNumber(answer);
    return unit == null ? number : '$number $unit';
  }

  /// "299792458" → "299.792.458"; "1969" → "1969".
  static String formatNumber(int n) {
    final digits = n.abs().toString();
    if (digits.length < 5) return n.toString();
    final buffer = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  String toString() => 'FactItem($id, $question)';
}
