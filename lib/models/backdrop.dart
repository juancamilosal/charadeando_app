import 'package:flutter/material.dart';

/// Cómo se ven las tarjetas de las categorías sobre el fondo.
enum CardStyle {
  /// De su color, con borde blanco y sombra sólida, como una calcomanía.
  sticker,

  /// Blancas, con borde y título del color de la categoría.
  white,

  /// De su color, con borde y sombra oscuros, como un cómic.
  comic,
}

/// Fondo de la app, de un solo color. Lo elige el usuario en "Fondos" y se
/// guarda en el celular.
enum Backdrop {
  uva('Uva', Color(0xFF6A1BE0), CardStyle.sticker),
  noche('Noche', Color(0xFF1B1446), CardStyle.sticker),
  crema('Crema', Color(0xFFFFF4DE), CardStyle.white, light: true),
  mostaza('Mostaza', Color(0xFFFFD23F), CardStyle.comic, light: true),
  coral('Coral', Color(0xFFFF5A5F), CardStyle.sticker),
  turquesa('Turquesa', Color(0xFF0FA3A3), CardStyle.sticker);

  const Backdrop(this.label, this.color, this.cards, {this.light = false});

  /// El que viene elegido.
  static const standard = uva;

  final String label;
  final Color color;
  final CardStyle cards;

  /// Fondo claro: los textos y botones sobre él van oscuros.
  final bool light;

  /// Color de los textos y los íconos que van directo sobre el fondo.
  Color get onColor => light ? const Color(0xFF2B0A57) : Colors.white;

  static Backdrop byName(String? name) =>
      values.firstWhere((b) => b.name == name, orElse: () => standard);
}
