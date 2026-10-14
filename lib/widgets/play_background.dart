import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'shine.dart';

/// Fondo de las pantallas: el que eligió el usuario en "Fondos".
/// Algunos momentos del juego (la cuenta regresiva) llevan su propio
/// degradado en [colors]. Envuelve un [Scaffold] transparente.
class PlayBackground extends StatelessWidget {
  const PlayBackground({super.key, required this.child, this.colors});

  final Widget child;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final backdrop = context.backdrop;
    final colors = this.colors ?? backdrop.gradient;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: this.colors == null && backdrop.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: colors == null
            ? BoxDecoration(color: backdrop.color)
            : BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
        // El fondo Oro brilla de vez en cuando, detrás de todo.
        child: this.colors == null && backdrop.shiny
            ? Stack(
                children: [
                  const Positioned.fill(child: Shine()),
                  child,
                ],
              )
            : child,
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
