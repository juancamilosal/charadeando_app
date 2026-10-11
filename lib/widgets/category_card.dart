import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'category_art.dart';

/// Tarjeta de una categoría: el dibujo grande arriba, el nombre y una
/// línea de texto debajo. Sirve para las categorías del juego y para las
/// propias.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.art,
    this.onTap,
    this.onLongPress,
    this.onMenu,
  });

  /// Tarjeta de una categoría del juego, con su GIF.
  factory CategoryCard.game(GameCategory category, {VoidCallback? onTap}) =>
      CategoryCard(
        title: category.label,
        subtitle: category.description,
        color: category.color,
        art: (size, onColor) =>
            CategoryArt(category: category, size: size, color: onColor),
        onTap: onTap,
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
  final String subtitle;
  final Color color;
  final Widget Function(double size, Color onColor) art;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Botón de tres puntos arriba a la derecha (editar, borrar…).
  final VoidCallback? onMenu;

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
    final onColor = color == AppColors.yellow ? AppColors.ink : Colors.white;
    final textScaler = MediaQuery.textScalerOf(context);

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                // El dibujo y los textos crecen con la tarjeta, para que se
                // vean igual en celulares angostos y anchos.
                builder: (context, box) {
                  final w = box.maxWidth;
                  final titleStyle = TextStyle(
                    fontFamily: AppFonts.display,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: onColor,
                  );
                  // Nunca se parte una palabra: si no cabe, se achica la
                  // letra; como último recurso, se corta con "…".
                  final titleSize = fitTitleSize(
                    title,
                    titleStyle,
                    width: w,
                    maxSize: w * 0.18,
                    minSize: w * 0.1,
                    textScaler: textScaler,
                  );
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
    );
  }
}
