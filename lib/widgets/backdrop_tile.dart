import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'category_card.dart';

/// Un recuadro de color que se puede tocar, con el estilo de las tarjetas
/// de categoría según el fondo: plano, calcomanía, blanco o cómic. [builder]
/// recibe el color de los textos y los íconos.
class BackdropTile extends StatelessWidget {
  const BackdropTile({
    super.key,
    required this.color,
    required this.onTap,
    required this.builder,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
  });

  final Color color;
  final VoidCallback? onTap;
  final Widget Function(Color onColor) builder;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final style = context.backdrop.cards;
    final onColor = style == CardStyle.white ? color : Colors.white;
    final (border, shadow) = switch (style) {
      CardStyle.flat => (
        null,
        const BoxShadow(
          color: Color(0x33000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ),
      CardStyle.sticker => (
        Colors.white,
        BoxShadow(
          color: context.backdrop.light
              ? const Color(0x33000000)
              : const Color(0x66000000),
          offset: const Offset(0, 5),
        ),
      ),
      CardStyle.comic => (
        AppColors.ink,
        const BoxShadow(color: AppColors.ink, offset: Offset(3, 5)),
      ),
      CardStyle.white => (
        color,
        const BoxShadow(
          color: Color(0x22000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ),
    };
    final inner = border == null ? radius : radius - 3;
    // Container (no DecoratedBox) para que el borde no quede debajo.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : Border.all(color: border, width: 3),
        boxShadow: [shadow],
      ),
      child: Material(
        color: style == CardStyle.white ? Colors.white : color,
        borderRadius: BorderRadius.circular(inner),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: builder(onColor)),
        ),
      ),
    );
  }
}

/// Dos botones del mismo tamaño, lado a lado: naranja a la izquierda y
/// morado a la derecha.
class PairButtons extends StatelessWidget {
  const PairButtons({super.key, required this.left, required this.right});

  final PairButton left;
  final PairButton right;

  @override
  Widget build(BuildContext context) {
    // La misma altura para los dos, con espacio para dos renglones.
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(68),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      ),
    );
  }
}

/// Uno de los [PairButtons]: ícono y texto, en un recuadro de color.
class PairButton extends StatelessWidget {
  const PairButton({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.6 : 1,
      child: BackdropTile(
        color: color,
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        onTap: onPressed,
        // Nunca se parte una palabra: si no cabe, se achica la letra.
        builder: (on) => LayoutBuilder(
          builder: (context, box) {
            final style = DefaultTextStyle.of(context).style.merge(
              TextStyle(
                fontFamily: AppFonts.display,
                height: 1.1,
                fontWeight: FontWeight.w600,
                color: on,
              ),
            );
            final textWidth = box.maxWidth - 28;
            final size = CategoryCard.fitTitleSize(
              label,
              style,
              width: textWidth,
              maxSize: 17,
              minSize: 12,
              textScaler: MediaQuery.textScalerOf(context),
            );
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: on, size: 22),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: style.copyWith(fontSize: size),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Botón de texto discreto, sobre el fondo: "← Salir de la categoría".
class QuietButton extends StatelessWidget {
  const QuietButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: context.onBackdrop.withValues(alpha: 0.85),
    );
    final text = Text(label);
    return icon == null
        ? TextButton(style: style, onPressed: onPressed, child: text)
        : TextButton.icon(
            style: style,
            icon: Icon(icon, size: 20),
            label: text,
            onPressed: onPressed,
          );
  }
}
