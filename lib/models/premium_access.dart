import 'category.dart';

/// Lo que el usuario tiene desbloqueado: Premium (comprado en Google Play o
/// con un código que abre todo) y las categorías sueltas que abrió con
/// códigos.
class PremiumAccess {
  const PremiumAccess({
    this.purchased = false,
    this.codeAll = false,
    this.codeCategories = const {},
  });

  factory PremiumAccess.fromJson(Map<String, dynamic> json) => PremiumAccess(
    purchased: json['compra'] == true,
    codeAll: json['codigo_todo'] == true,
    codeCategories: {
      for (final c in json['codigo_categorias'] as List? ?? const [])
        if (c is String) c,
    },
  );

  /// Compró Premium en Google Play.
  final bool purchased;

  /// Canjeó un código que abre todo.
  final bool codeAll;

  /// Códigos de las categorías (como `ANIME`) que abrió con códigos.
  final Set<String> codeCategories;

  /// Todo desbloqueado: categorías de pago, video Full HD y Máxima y
  /// categorías propias sin límite.
  bool get premium => purchased || codeAll;

  /// Si se puede jugar [category].
  bool unlocks(GameCategory category) =>
      !category.premium || premium || codeCategories.contains(category.code);

  PremiumAccess copyWith({
    bool? purchased,
    bool? codeAll,
    Set<String>? codeCategories,
  }) => PremiumAccess(
    purchased: purchased ?? this.purchased,
    codeAll: codeAll ?? this.codeAll,
    codeCategories: codeCategories ?? this.codeCategories,
  );

  Map<String, dynamic> toJson() => {
    'compra': purchased,
    'codigo_todo': codeAll,
    'codigo_categorias': codeCategories.toList()..sort(),
  };
}
