import 'package:flutter/material.dart';

/// Hace sonar el toque de los botones en toda la app: es la animación de
/// toque de Material (la que usan los botones, las tarjetas, las filas y los
/// interruptores) con sonido. Suena solo cuando el toque se completa (no al
/// deslizar ni al cancelar) y nunca en lo deshabilitado, que no se anima.
class TapSoundSplashFactory extends InteractiveInkFeatureFactory {
  const TapSoundSplashFactory({required this.onTap});

  /// Se llama en cada toque completado; decide si suena.
  final VoidCallback onTap;

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    return _SoundRipple(
      onTap: onTap,
      controller: controller,
      referenceBox: referenceBox,
      position: position,
      color: color,
      containedInkWell: containedInkWell,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
      radius: radius,
      onRemoved: onRemoved,
      textDirection: textDirection,
    );
  }
}

class _SoundRipple extends InkRipple {
  _SoundRipple({
    required this.onTap,
    required super.controller,
    required super.referenceBox,
    required super.position,
    required super.color,
    required super.textDirection,
    super.containedInkWell,
    super.rectCallback,
    super.borderRadius,
    super.customBorder,
    super.radius,
    super.onRemoved,
  });

  final VoidCallback onTap;

  @override
  void confirm() {
    onTap();
    super.confirm();
  }
}
