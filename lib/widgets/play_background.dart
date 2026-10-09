import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Fondo de colores de las pantallas. Envuelve un [Scaffold] transparente.
class PlayBackground extends StatelessWidget {
  const PlayBackground({
    super.key,
    required this.child,
    this.colors = AppColors.background,
  });

  final Widget child;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Tarjeta blanca para agrupar contenido sobre el fondo de colores.
class PlayPanel extends StatelessWidget {
  const PlayPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: padding, child: child),
    );
  }
}
