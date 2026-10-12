import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/art_cycle.dart';
import '../widgets/category_card.dart';
import '../widgets/combine_categories_sheet.dart';
import '../widgets/play_background.dart';
import '../widgets/play_choice.dart';

/// Elección de la categoría. "Todas" muestra Libre como una franja, el
/// botón "Combinar categorías" y las categorías del juego por secciones
/// (Especiales, Entretenimiento, Cultura general, Deportes y Clásicos);
/// "Mías", las categorías que creó el usuario. Libre deja elegir entre
/// palabras manuales y automáticas; las demás preguntan si se juega una
/// partida rápida o personalizada.
class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key});

  /// Espacio entre tarjetas y proporción (ancho / alto) de cada una, en
  /// "Mías" (2 columnas) y en las secciones (3 columnas).
  static const gridSpacing = 14.0;
  static const cardAspect = 0.7;
  static const sectionSpacing = 10.0;
  static const sectionAspect = 0.74;

  void _choose(BuildContext context, WidgetRef ref, GameCategory category) {
    if (!category.available) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '¡Pronto! Estamos preparando las palabras de '
              '${category.label}.',
            ),
          ),
        );
      return;
    }
    final controller = ref.read(gameControllerProvider.notifier);
    final config = ref
        .read(gameControllerProvider)
        .config
        // Por defecto se juega sin grupos; se cambia en la configuración.
        .copyWith(
          category: category,
          clearCustomCategory: true,
          clearMix: true,
          inGroups: false,
        );
    if (category == GameCategory.free) {
      controller.configure(config);
      context.go(Routes.freeMode);
      return;
    }
    controller.configure(config.copyWith(wordSource: WordSource.random));
    choosePlay(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(customCategoriesProvider);
    final tab = data.value?.tab ?? CategoryTab.all;
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          // En celulares angostos se achica para caber.
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Selección de categoría'),
          ),
          titleSpacing: 20,
          // Es la primera pantalla: no hay a dónde volver.
          automaticallyImplyLeading: false,
        ),
        // Los dibujos de las categorías se animan uno por uno.
        body: ArtCycle(
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                CategoryTabSelector(
                  selected: tab,
                  onChanged: (t) =>
                      ref.read(customCategoriesProvider.notifier).setTab(t),
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: tab == CategoryTab.all
                      ? KeyedSubtree(
                          key: const ValueKey('todas'),
                          child: _allCategories(context, ref),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('mias'),
                          child: _MyCategories(data: data),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _allCategories(BuildContext context, WidgetRef ref) {
    final today = ref.watch(clockProvider)();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Libre, aparte: una franja ancha.
        CategoryStrip(
          category: GameCategory.free,
          onTap: () => _choose(context, ref, GameCategory.free),
        ),
        const SizedBox(height: 14),
        // Jugar con palabras de varias categorías a la vez.
        _CombineButton(
          onTap: () async {
            if (await showCombineCategories(context) == true &&
                context.mounted) {
              await choosePlay(context, ref);
            }
          },
        ),
        for (final (section, categories) in GameCategory.sectionsOn(today)) ...[
          const SizedBox(height: 26),
          CategorySectionHeader(section: section, count: categories.length),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: sectionSpacing,
            crossAxisSpacing: sectionSpacing,
            childAspectRatio: sectionAspect,
            children: [
              for (final category in categories)
                CategoryCard.game(
                  category,
                  compact: true,
                  onTap: () => _choose(context, ref, category),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Título de una sección a la izquierda y, a la derecha, cuántas
/// categorías tiene (o su nota, como "Solo por temporada").
class CategorySectionHeader extends StatelessWidget {
  const CategorySectionHeader({
    super.key,
    required this.section,
    required this.count,
  });

  final CategorySection section;
  final int count;

  @override
  Widget build(BuildContext context) {
    final onBackdrop = context.onBackdrop;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            section.title,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 22,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: onBackdrop,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          section.note ?? '$count ${count == 1 ? 'categoría' : 'categorías'}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: onBackdrop.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

Widget _grid(List<Widget> children) => GridView.count(
  crossAxisCount: 2,
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  mainAxisSpacing: CategoryScreen.gridSpacing,
  crossAxisSpacing: CategoryScreen.gridSpacing,
  childAspectRatio: CategoryScreen.cardAspect,
  children: children,
);

/// Selector "Todas | Mías" con forma de píldora. La opción elegida va en
/// blanco con el texto morado; la otra, transparente con borde blanco.
class CategoryTabSelector extends StatelessWidget {
  const CategoryTabSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final CategoryTab selected;
  final ValueChanged<CategoryTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final onBackdrop = context.onBackdrop;
    Widget option(CategoryTab tab, String label, IconData? icon) {
      final on = tab == selected;
      final color = !on
          ? onBackdrop
          : context.backdrop.light
          ? Colors.white
          : AppColors.purple;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: on ? onBackdrop : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: onBackdrop, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: color),
                    const SizedBox(width: 6),
                  ],
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 220),
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    child: Text(label),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(CategoryTab.all, 'Todas', null),
        const SizedBox(width: 10),
        option(CategoryTab.mine, 'Mías', Icons.auto_awesome),
      ],
    );
  }
}

/// Pestaña "Mías": la tarjeta para crear una categoría y las del usuario.
class _MyCategories extends ConsumerWidget {
  const _MyCategories({required this.data});

  final AsyncValue<CustomCategoriesData> data;

  void _create(BuildContext context, WidgetRef ref) {
    if (!ref.read(customCategoriesProvider.notifier).canCreate) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Para crear más categorías necesitas premium.'),
          ),
        );
      return;
    }
    context.push(Routes.customCategory);
  }

  void _play(BuildContext context, WidgetRef ref, CustomCategory category) {
    if (!category.playable) {
      final missing = category.missingWords;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'A "${category.name}" le faltan $missing '
              '${missing == 1 ? 'palabra' : 'palabras'} para jugar.',
            ),
            action: SnackBarAction(
              label: 'Completar',
              onPressed: () =>
                  context.push(Routes.customCategory, extra: category),
            ),
          ),
        );
      return;
    }
    final config = ref.read(gameControllerProvider).config;
    ref
        .read(gameControllerProvider.notifier)
        .configure(
          config.copyWith(
            category: GameCategory.free,
            customCategory: category,
            clearMix: true,
            wordSource: WordSource.random,
            inGroups: false,
          ),
        );
    choosePlay(context, ref);
  }

  Future<void> _options(
    BuildContext context,
    WidgetRef ref,
    CustomCategory category,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                category.name,
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.purple),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(context, 'editar'),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.coral),
              title: const Text('Borrar'),
              onTap: () => Navigator.pop(context, 'borrar'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'editar') {
      context.push(Routes.customCategory, extra: category);
    } else if (action == 'borrar') {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('¿Borrar "${category.name}"?'),
          content: Text(
            'Se borrarán sus ${category.wordsLabel}. No se puede deshacer.',
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.purple),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Borrar'),
            ),
          ],
        ),
      );
      if (sure == true) {
        await ref.read(customCategoriesProvider.notifier).delete(category.id);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = data.value?.categories;
    final onBackdrop = context.onBackdrop;
    if (categories == null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: onBackdrop)),
      );
    }
    if (categories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Icon(
            Icons.auto_awesome,
            size: 64,
            color: context.backdrop.light ? AppColors.orange : AppColors.yellow,
          ),
          const SizedBox(height: 12),
          Text(
            'Crea una categoría con tus propias palabras',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: onBackdrop,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '"Mi familia", "La oficina"…',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: onBackdrop.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Crear mi primera categoría'),
            onPressed: () => _create(context, ref),
          ),
        ],
      );
    }
    return _grid([
      _NewCategoryCard(onTap: () => _create(context, ref)),
      for (final c in categories)
        CategoryCard.custom(
          c,
          onTap: () => _play(context, ref, c),
          onLongPress: () => _options(context, ref, c),
          onMenu: () => _options(context, ref, c),
        ),
    ]);
  }
}

/// Primera tarjeta de "Mías": crear una categoría nueva.
class _NewCategoryCard extends StatelessWidget {
  const _NewCategoryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onBackdrop = context.onBackdrop;
    return Material(
      color: onBackdrop.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: onBackdrop, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle, size: 64, color: onBackdrop),
              const SizedBox(height: 10),
              Text(
                'Nueva categoría',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: onBackdrop,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón "Combinar categorías": con borde punteado y un fondo apenas
/// marcado, en el color de los textos del fondo, para que se distinga de
/// las tarjetas.
class _CombineButton extends StatelessWidget {
  const _CombineButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onBackdrop = context.onBackdrop;
    return CustomPaint(
      foregroundPainter: _DashedBorder(color: onBackdrop, radius: 20),
      child: Material(
        color: onBackdrop.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shuffle, color: onBackdrop, size: 26),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Combinar categorías',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: onBackdrop,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Borde punteado redondeado.
class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dash = 8.0;
  static const _gap = 6.0;
  static const _width = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_width / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
