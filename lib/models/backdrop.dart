import 'package:flutter/material.dart';

/// Cómo se ven las tarjetas de las categorías sobre el fondo.
enum CardStyle {
  /// De su color, sin borde: las de siempre.
  flat,

  /// De su color, con borde blanco y sombra sólida, como una calcomanía.
  sticker,

  /// Blancas, con borde y título del color de la categoría.
  white,

  /// De su color, con borde y sombra oscuros, como un cómic.
  comic,

  /// De su color, con borde dorado y sombra oscura: el fondo Oro.
  gold,
}

/// Fondo de la app. Lo elige el usuario en "Fondos" y se guarda en el
/// celular. El clásico es un degradado; los demás, de un solo color.
enum Backdrop {
  clasico(
    'Clásico',
    Color(0xFFC21FD6),
    CardStyle.sticker,
    gradient: [Color(0xFF7B2FF7), Color(0xFFC21FD6), Color(0xFFFF4F8B)],
  ),
  uva('Uva', Color(0xFF6A1BE0), CardStyle.sticker),
  noche('Noche', Color(0xFF1B1446), CardStyle.sticker),
  crema('Crema', Color(0xFFFFF4DE), CardStyle.white, light: true),
  mostaza('Mostaza', Color(0xFFFFD23F), CardStyle.comic, light: true),
  coral('Coral', Color(0xFFFF5A5F), CardStyle.sticker),
  turquesa('Turquesa', Color(0xFF0FA3A3), CardStyle.sticker),

  /// Exclusivo de Todo Charadeando: morado oscuro con dorado.
  oro(
    'Oro',
    Color(0xFF2C0E52),
    CardStyle.gold,
    gradient: [Color(0xFF14062A), Color(0xFF3A1266), Color(0xFF14062A)],
    premium: true,
  );

  const Backdrop(
    this.label,
    this.color,
    this.cards, {
    this.light = false,
    this.gradient,
    this.premium = false,
  });

  /// El dorado del fondo Oro (bordes y títulos).
  static const gold = Color(0xFFFFC21A);

  /// El que viene elegido.
  static const standard = clasico;

  final String label;

  /// El color del fondo; en el degradado, el del medio.
  final Color color;

  /// Los colores del degradado, de arriba a la izquierda hacia abajo a la
  /// derecha, o null si es de un solo color.
  final List<Color>? gradient;
  final CardStyle cards;

  /// Fondo claro: los textos y botones sobre él van oscuros.
  final bool light;

  /// Solo con Todo Charadeando.
  final bool premium;

  /// Color de los textos y los íconos que van directo sobre el fondo.
  Color get onColor => light ? const Color(0xFF2B0A57) : Colors.white;

  /// El fondo que se usa: uno exclusivo solo si tiene Todo Charadeando
  /// ([premium]); si no, el que viene elegido.
  Backdrop allowedWith({required bool premium}) =>
      this.premium && !premium ? standard : this;

  static Backdrop byName(String? name) =>
      values.firstWhere((b) => b.name == name, orElse: () => standard);
}
