import 'dart:math';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'category_art.dart';

/// Tarjeta de una categoría: el dibujo grande arriba y el nombre debajo
/// (las propias, también cuántas palabras tienen). Su estilo (calcomanía, blanca o cómic) depende
/// del fondo elegido. Sirve para las categorías del juego y para las
/// propias.
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
    this.sameSizeAs = const [],
  });

  /// Tarjeta de una categoría del juego, con su GIF.
  factory CategoryCard.game(GameCategory category, {VoidCallback? onTap}) =>
      CategoryCard(
        title: category.label,
        color: category.color,
        art: (size, onColor) =>
            CategoryArt(category: category, size: size, color: onColor),
        onTap: onTap,
        sameSizeAs: [for (final c in GameCategory.values) c.label],
      );

  /// Tarjeta de una categoría propia: su ícono, su color y cuántas palabras
  /// tiene.
  factory CategoryCard.custom(
    CustomCategory category, {
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    VoidCallback? onMenu,
  }) => CategoryCard(
    title: category.name.trim().isEmpty ? 'Mi categoría' : category.name,
    subtitle: category.wordsLabel,
    color: category.color,
    art: (size, onColor) =>
        Icon(category.icon, size: size * 0.8, color: onColor),
    onTap: onTap,
    onLongPress: onLongPress,
    onMenu: onMenu,
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

  /// Otros nombres que deben verse del mismo tamaño que [title]: la letra
  /// es la más grande con la que caben todos, para que las tarjetas no
  /// queden disparejas.
  final List<String> sameSizeAs;

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
    final style = context.backdrop.cards;
    // En las tarjetas blancas, el dibujo y los textos van del color de la
    // categoría.
    final onColor = style == CardStyle.white
        ? color
        : color == AppColors.yellow
        ? AppColors.ink
        : Colors.white;
    final textScaler = MediaQuery.textScalerOf(context);

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
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
                child: LayoutBuilder(
                  // El dibujo y los textos crecen con la tarjeta, para que se
                  // vean igual en celulares angostos y anchos.
                  builder: (context, box) {
                    // El nombre usa todo el ancho; el dibujo y los tamaños
                    // se miden como si hubiera 16 de margen a cada lado.
                    final full = box.maxWidth;
                    final w = full - 16;
                    // Con el estilo que hereda (por ejemplo, el espacio
                    // entre letras del tema), para medirlo igual que se
                    // dibuja.
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
                    final titleSize = [title, ...sameSizeAs]
                        .map(
                          (t) => fitTitleSize(
                            t,
                            titleStyle,
                            width: full,
                            maxSize: w * 0.23,
                            minSize: w * 0.12,
                            textScaler: textScaler,
                          ),
                        )
                        .reduce(min);
                    // La columna ocupa todo el ancho: con textos cortos
                    // quedaba angosta y pegada a la izquierda.
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          // Si los textos ocupan más (letra grande en el
                          // celular), el dibujo se achica para caber.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: art(w * 0.75, onColor),
                          ),
                        ),
                        const SizedBox(height: 8),
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
              if (onMenu != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: Icon(Icons.more_vert, color: onColor),
                    tooltip: 'Opciones',
                    onPressed: onMenu,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
