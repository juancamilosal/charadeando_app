import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'category_art.dart';

/// Tarjeta de una categoría: el dibujo grande arriba y el nombre debajo
/// (las propias, también cuántas palabras tienen). Su estilo (calcomanía,
/// blanca o cómic) depende del fondo elegido. Sirve para las categorías del
/// juego y para las propias.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.color,
    required this.art,
    this.onTap,
    this.onLongPress,
    this.onMenu,
    this.compact = false,
    this.isNew = false,
    this.soon = false,
    this.locked = false,
  });

  /// Tarjeta de una categoría del juego, con su imagen (o su ícono, si todavía
  /// no tiene), y sus etiquetas "Nueva" y "Pronto". [color] cambia el de la
  /// categoría (por ejemplo, por el de su sección). [locked]: es de pago y
  /// todavía no se tiene.
  factory CategoryCard.game(
    GameCategory category, {
    VoidCallback? onTap,
    bool compact = false,
    Color? color,
    bool locked = false,
  }) => CategoryCard(
    title: category.label,
    color: color ?? category.color,
    art: (size, onColor) =>
        CategoryArt(category: category, size: size, color: onColor),
    onTap: onTap,
    compact: compact,
    isNew: category.isNew,
    soon: !category.available,
    locked: locked,
  );

  /// Tarjeta de una categoría propia: su ícono, su color y cuántas palabras
  /// tiene.
  factory CategoryCard.custom(
    CustomCategory category, {
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    VoidCallback? onMenu,
    bool compact = false,
  }) => CategoryCard(
    title: category.name.trim().isEmpty ? 'Mi categoría' : category.name,
    subtitle: category.wordsLabel,
    color: category.color,
    art: (size, onColor) =>
        Icon(category.icon, size: size * 0.8, color: onColor),
    onTap: onTap,
    onLongPress: onLongPress,
    onMenu: onMenu,
    compact: compact,
  );

  final String title;

  /// Línea debajo del nombre, o null si no lleva.
  final String? subtitle;
  final Color color;
  final Widget Function(double size, Color onColor) art;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Botón de tres puntos arriba a la derecha (editar, borrar…).
  final VoidCallback? onMenu;

  /// Más pequeña, para la cuadrícula de 3 columnas de las secciones.
  final bool compact;

  /// Etiqueta amarilla "Nueva" arriba a la izquierda.
  final bool isNew;

  /// Todavía no tiene palabras: el dibujo se ve apagado, con "Pronto".
  final bool soon;

  /// De pago sin desbloquear: un candado amarillo arriba a la derecha. Se
  /// ve con todos sus colores, para que den ganas de abrirla.
  final bool locked;

  /// Tamaño de letra más grande, hasta [maxSize], con el que [text] cabe en
  /// [maxLines] renglones de [width] sin partir ninguna palabra. Si ni con
  /// [minSize] cabe, devuelve [minSize] y el texto se corta con "…".
  static double fitTitleSize(
    String text,
    TextStyle style, {
    required double width,
    required double maxSize,
    required double minSize,
    int maxLines = 2,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    for (var size = maxSize; size > minSize; size -= 0.5) {
      final s = style.copyWith(fontSize: size);
      final longest = words.fold<double>(0, (widest, word) {
        final p = TextPainter(
          text: TextSpan(text: word, style: s),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        return widest > p.width ? widest : p.width;
      });
      if (longest > width) continue;
      final all = TextPainter(
        text: TextSpan(text: text, style: s),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: maxLines,
      )..layout(maxWidth: width);
      if (!all.didExceedMaxLines) return size;
    }
    return minSize;
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return CategoryCardFrame(
      color: color,
      onTap: onTap,
      onLongPress: onLongPress,
      builder: (onColor) => Stack(
        children: [
          Padding(
            padding: compact
                ? const EdgeInsets.fromLTRB(5, 8, 5, 10)
                : const EdgeInsets.fromLTRB(8, 16, 8, 16),
            child: LayoutBuilder(
              // El dibujo y los textos crecen con la tarjeta, para que se
              // vean igual en celulares angostos y anchos.
              builder: (context, box) {
                // El nombre usa todo el ancho; en las grandes, el dibujo y
                // los tamaños se miden como si hubiera 16 de margen a cada
                // lado.
                final full = box.maxWidth;
                final w = compact ? full : full - 16;
                // Con el estilo que hereda (por ejemplo, el espacio entre
                // letras del tema), para medirlo igual que se dibuja.
                final titleStyle = DefaultTextStyle.of(context).style.merge(
                  TextStyle(
                    fontFamily: AppFonts.display,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: onColor,
                  ),
                );
                // Nunca se parte una palabra: si no cabe, se achica la
                // letra; como último recurso, se corta con "…".
                final titleSize = fitTitleSize(
                  title,
                  titleStyle,
                  width: full,
                  maxSize: w * (compact ? 0.23 : 0.25),
                  minSize: w * 0.12,
                  textScaler: textScaler,
                );
                final picture = FittedBox(
                  fit: BoxFit.scaleDown,
                  child: art(w * (compact ? 0.76 : 0.75), onColor),
                );
                // La columna ocupa todo el ancho: con textos cortos
                // quedaba angosta y pegada a la izquierda.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      // Si los textos ocupan más (letra grande en el
                      // celular), el dibujo se achica para caber.
                      child: soon
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                Opacity(opacity: 0.4, child: picture),
                                const CategoryBadge.soon(),
                              ],
                            )
                          : picture,
                    ),
                    SizedBox(height: compact ? 6 : 8),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: titleStyle.copyWith(fontSize: titleSize),
                    ),
                    if (subtitle case final subtitle?) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: w * 0.105,
                          fontWeight: FontWeight.w700,
                          color: onColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          if (isNew)
            const Positioned(top: 6, left: 6, child: CategoryBadge.isNew()),
          if (locked)
            Positioned(
              top: compact ? 6 : 10,
              right: compact ? 6 : 10,
              child: const LockBadge(),
            ),
          if (onMenu != null)
            Positioned(
              top: compact ? 0 : 4,
              right: compact ? 0 : 4,
              child: IconButton(
                visualDensity: compact ? VisualDensity.compact : null,
                iconSize: compact ? 20 : null,
                icon: Icon(Icons.more_vert, color: onColor),
                tooltip: 'Opciones',
                onPressed: onMenu,
              ),
            ),
        ],
      ),
    );
  }
}

/// El marco de una tarjeta de categoría, con el estilo del fondo:
/// calcomanía (borde blanco), blanca (borde del color), cómic (borde y
/// sombra oscuros) o lisa. [builder] recibe el color del dibujo y los
/// textos.
class CategoryCardFrame extends StatelessWidget {
  const CategoryCardFrame({
    super.key,
    required this.color,
    required this.builder,
    this.onTap,
    this.onLongPress,
  });

  final Color color;
  final Widget Function(Color onColor) builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final style = context.backdrop.cards;
    // En las tarjetas blancas, el dibujo y los textos van del color de la
    // categoría (el amarillo, en naranja: sobre blanco no se lee); sobre el
    // amarillo, oscuros.
    final onColor = style == CardStyle.white
        ? (color == AppColors.yellow ? AppColors.orange : color)
        : color == AppColors.yellow
        ? AppColors.ink
        : Colors.white;

    // Las de borde quedan un poco más adentro.
    final radius = style == CardStyle.flat ? 24.0 : 21.0;
    final (border, shadow) = switch (style) {
      CardStyle.flat => (null, null),
      CardStyle.sticker => (
        Colors.white,
        BoxShadow(
          color: context.backdrop.light
              ? const Color(0x33000000)
              : const Color(0x66000000),
          offset: const Offset(0, 6),
        ),
      ),
      CardStyle.comic => (
        AppColors.ink,
        const BoxShadow(color: AppColors.ink, offset: Offset(4, 6)),
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
    // Container (no DecoratedBox) para que el borde no quede debajo de la
    // tarjeta.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: border == null ? null : Border.all(color: border, width: 3),
        boxShadow: [?shadow],
      ),
      child: Material(
        color: style == CardStyle.white ? Colors.white : color,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          onLongPress: onLongPress,
          child: builder(onColor),
        ),
      ),
    );
  }
}

/// Etiqueta pequeña de una tarjeta: "Nueva" (amarilla) o "Pronto" (oscura).
class CategoryBadge extends StatelessWidget {
  const CategoryBadge.isNew({super.key})
    : text = 'Nueva',
      background = AppColors.yellow,
      foreground = AppColors.ink;

  const CategoryBadge.soon({super.key})
    : text = 'Pronto',
      background = AppColors.ink,
      foreground = Colors.white;

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        text,
        // Siempre del mismo tamaño: es una etiqueta, no un texto para leer
        // con letra grande.
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

/// Candado de lo que se desbloquea con Premium: un círculo amarillo con
/// borde blanco.
class LockBadge extends StatelessWidget {
  const LockBadge({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Premium',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.yellow,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              offset: Offset(0, 2),
              blurRadius: 3,
            ),
          ],
        ),
        child: Icon(Icons.lock, size: size * 0.54, color: AppColors.ink),
      ),
    );
  }
}
