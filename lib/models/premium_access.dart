import 'category.dart';

/// Lo que el usuario tiene desbloqueado: Premium (comprado en Google Play o
/// con un código que abre todo) y las categorías sueltas que compró o abrió
/// con códigos.
class PremiumAccess {
  const PremiumAccess({
    this.purchased = false,
    this.codeAll = false,
    this.codeCategories = const {},
    this.boughtCategories = const {},
  });

  factory PremiumAccess.fromJson(Map<String, dynamic> json) => PremiumAccess(
    purchased: json['compra'] == true,
    codeAll: json['codigo_todo'] == true,
    codeCategories: {
      for (final c in json['codigo_categorias'] as List? ?? const [])
        if (c is String) c,
    },
    boughtCategories: {
      for (final c in json['compra_categorias'] as List? ?? const [])
        if (c is String) c,
    },
  );

  /// Compró Premium en Google Play.
  final bool purchased;

  /// Canjeó un código que abre todo.
  final bool codeAll;

  /// Códigos de las categorías (como `ANIME`) que abrió con códigos.
  final Set<String> codeCategories;

  /// Códigos de las categorías compradas sueltas en Google Play.
  final Set<String> boughtCategories;

  /// Las categorías sueltas que tiene, compradas o con códigos.
  Set<String> get categories => {...codeCategories, ...boughtCategories};

  /// Todo desbloqueado: categorías de pago, video Full HD y Máxima y
  /// categorías propias sin límite.
  bool get premium => purchased || codeAll;

  /// Puede usar el modo "Celular juez" (puede usar el juez), que es de
  /// pago. Todo el acceso pasa por aquí: para darlo por un tiempo (por
  /// ejemplo, un mes de prueba) basta con cambiar esta función, con [now]
  /// para comparar la fecha.
  bool canUseJudge([DateTime? now]) => premium;

  /// No tiene nada desbloqueado (ni compras ni códigos).
  bool get nothing =>
      !purchased &&
      !codeAll &&
      codeCategories.isEmpty &&
      boughtCategories.isEmpty;

  /// Si se puede jugar [category].
  bool unlocks(GameCategory category) =>
      !category.premium || premium || categories.contains(category.code);

  PremiumAccess copyWith({
    bool? purchased,
    bool? codeAll,
    Set<String>? codeCategories,
    Set<String>? boughtCategories,
  }) => PremiumAccess(
    purchased: purchased ?? this.purchased,
    codeAll: codeAll ?? this.codeAll,
    codeCategories: codeCategories ?? this.codeCategories,
    boughtCategories: boughtCategories ?? this.boughtCategories,
  );

  /// Junta lo de los dos: nada desbloqueado se pierde.
  PremiumAccess merge(PremiumAccess other) => PremiumAccess(
    purchased: purchased || other.purchased,
    codeAll: codeAll || other.codeAll,
    codeCategories: {...codeCategories, ...other.codeCategories},
    boughtCategories: {...boughtCategories, ...other.boughtCategories},
  );

  Map<String, dynamic> toJson() => {
    'compra': purchased,
    'codigo_todo': codeAll,
    'codigo_categorias': codeCategories.toList()..sort(),
    'compra_categorias': boughtCategories.toList()..sort(),
  };
}
