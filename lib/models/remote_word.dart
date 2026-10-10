import 'word.dart';

/// Palabra guardada en Directus.
class RemoteWord {
  const RemoteWord({
    required this.id,
    required this.frase,
    required this.categoria,
  });

  factory RemoteWord.fromJson(Map<String, dynamic> json) => RemoteWord(
    id: '${json['id']}',
    frase: '${json['frase'] ?? ''}',
    categoria: '${json['categoria'] ?? ''}',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'frase': frase,
    'categoria': categoria,
  };

  /// Las palabras de Gemini no tienen id ni categoría.
  Word toWord() => Word(
    frase,
    category: categoria.isEmpty ? null : categoria,
    id: id.isEmpty ? null : id,
  );

  final String id;
  final String frase;
  final String categoria;
}
