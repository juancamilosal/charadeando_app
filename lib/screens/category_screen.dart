import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets/category_art.dart';
import '../widgets/play_background.dart';
import '../widgets/roulette_banner.dart';

/// Elección de la categoría. "Libre" explica el juego y deja elegir entre
/// palabras manuales y automáticas; las demás explican el juego con
/// ejemplos de su categoría y siguen a la configuración con palabras
/// automáticas.
class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key});

  /// Espacio entre tarjetas y proporción (ancho / alto) de cada una.
  static const _gridSpacing = 14.0;
  static const _cardAspect = 0.7;

  void _choose(BuildContext context, WidgetRef ref, GameCategory category) {
    final controller = ref.read(gameControllerProvider.notifier);
    final config = ref.read(gameControllerProvider).config;
    if (category == GameCategory.free) {
      controller.configure(config.copyWith(category: category));
      context.go(Routes.freeMode);
      return;
    }
    controller.configure(
      config.copyWith(category: category, wordSource: WordSource.random),
    );
    context.go(Routes.categoryIntro);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Categorías'),
          leading: BackButton(onPressed: () => context.go(Routes.welcome)),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const Text(
                '¿Con qué palabras quieren jugar?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              // Libre es una tarjeta igual a las demás, centrada y del
              // tamaño de las de la cuadrícula.
              LayoutBuilder(
                builder: (context, box) {
                  final width = (box.maxWidth - _gridSpacing) / 2;
                  return Center(
                    child: SizedBox(
                      width: width,
                      height: width / _cardAspect,
                      child: _CategoryCard(
                        category: GameCategory.free,
                        onTap: () => _choose(context, ref, GameCategory.free),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Categorías',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: _gridSpacing,
                crossAxisSpacing: _gridSpacing,
                childAspectRatio: _cardAspect,
                children: [
                  for (final category in GameCategory.themed)
                    _CategoryCard(
                      category: category,
                      onTap: () => _choose(context, ref, category),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              // Sección aparte, no es una categoría de palabras.
              RouletteBanner(onTap: () => context.go(Routes.punishments)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final GameCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onColor = category.color == AppColors.yellow
        ? AppColors.ink
        : Colors.white;
    Widget title(double size) => Text(
      category.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppFonts.display,
        fontSize: size,
        height: 1.1,
        fontWeight: FontWeight.w600,
        color: onColor,
      ),
    );
    Widget description(double size) => Text(
      category.description,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: onColor.withValues(alpha: 0.85),
      ),
    );

    return Material(
      color: category.color,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                // El dibujo y los textos crecen con la tarjeta, para
                // que se vean igual en celulares angostos y anchos.
                builder: (context, box) {
                  final w = box.maxWidth;
                  // Ocupa todo el ancho de la tarjeta: con nombre y
                  // descripción cortos ("Deportes") la columna quedaba
                  // angosta y pegada a la izquierda.
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        // Si los textos ocupan más (letra grande en el
                        // celular), el dibujo se achica para caber.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CategoryArt(
                            category: category,
                            size: w * 0.75,
                            color: onColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Una sola palabra larga ("Celebridades") se
                      // achica en vez de partirse en dos renglones.
                      if (category.label.contains(' '))
                        title(w * 0.18)
                      else
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: title(w * 0.18),
                        ),
                      const SizedBox(height: 4),
                      description(w * 0.105),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
