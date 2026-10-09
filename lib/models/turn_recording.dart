/// Cómo se ve un texto dentro del video del turno.
enum CaptionStyle {
  /// Presentación del turno durante la cuenta regresiva.
  title,

  /// La palabra que se está adivinando.
  word,

  /// Aviso de acierto.
  hit,

  /// Aviso de que se pasó la palabra.
  pass,
}

/// Un texto que aparece en el video entre [start] y [end], medidos desde el
/// inicio del video del turno.
class Caption {
  const Caption(this.text, this.style, this.start, this.end);

  final String text;
  final CaptionStyle style;
  final Duration start;
  final Duration end;
}

/// Lo que se grabó en un turno: las partes de video, en orden, y los textos
/// que se escriben encima. Hay más de una parte cuando el turno se pausó,
/// porque al salir de la app el sistema le quita la cámara.
class TurnRecording {
  const TurnRecording({
    required this.segments,
    required this.captions,
    required this.duration,
  });

  final List<String> segments;
  final List<Caption> captions;

  /// Duración total grabada, sumando todas las partes.
  final Duration duration;

  bool get isEmpty => segments.isEmpty;
}
