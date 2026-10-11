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
import '../widgets/play_background.dart';
import '../widgets/roulette_banner.dart';

/// Elección de la categoría. "Todas" muestra Libre, las categorías del
/// juego y la Ruleta de castigos; "Mías", las categorías que creó el
/// usuario. Libre explica el juego y deja elegir entre palabras manuales y
/// automáticas; las demás explican el juego y siguen a la configuración.
class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key});

  /// Espacio entre tarjetas y proporción (ancho / alto) de cada una.
  static const gridSpacing = 14.0;
  static const cardAspect = 0.7;

  void _choose(BuildContext context, WidgetRef ref, GameCategory category) {
    final controller = ref.read(gameControllerProvider.notifier);
    final config = ref
        .read(gameControllerProvider)
        .config
        // Por defecto se juega sin grupos; se cambia en "¿Cómo se juega?".
        .copyWith(
          category: category,
          clearCustomCategory: true,
          inGroups: false,
        );
    if (category == GameCategory.free) {
      controller.configure(config);
      context.go(Routes.freeMode);
      return;
    }
    controller.configure(config.copyWith(wordSource: WordSource.random));
    context.go(Routes.categoryIntro);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(customCategoriesProvider);
    final tab = data.value?.tab ?? CategoryTab.all;
    final onBackdrop = context.onBackdrop;
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Selección de categoría'),
          // Es la primera pantalla: no hay a dónde volver.
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.palette_outlined),
              tooltip: 'Fondos',
              onPressed: () => context.push(Routes.backdrops),
            ),
            IconButton(
              icon: const Icon(Icons.video_library_outlined),
              tooltip: 'Mis videos',
              onPressed: () => context.push(Routes.myVideos),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Cómo se juega',
              onPressed: () => context.push(Routes.welcome),
            ),
          ],
        ),
        // Los dibujos de las categorías se animan uno por uno.
        body: ArtCycle(
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  '¿Con qué palabras quieren jugar?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: onBackdrop,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                CategoryTabSelector(
                  selected: tab,
                  onChanged: (t) =>
                      ref.read(customCategoriesProvider.notifier).setTab(t),
                ),
                const SizedBox(height: 18),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Libre es una tarjeta igual a las demás, centrada y del tamaño de
        // las de la cuadrícula.
        LayoutBuilder(
          builder: (context, box) {
            final width = (box.maxWidth - gridSpacing) / 2;
            return Center(
              child: SizedBox(
                width: width,
                height: width / cardAspect,
                child: CategoryCard.game(
                  GameCategory.free,
                  onTap: () => _choose(context, ref, GameCategory.free),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Categorías',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.display,
            color: context.onBackdrop,
            fontSize: 38,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _grid([
          for (final category in GameCategory.themed)
            CategoryCard.game(
              category,
              onTap: () => _choose(context, ref, category),
            ),
        ]),
        const SizedBox(height: 28),
        // Sección aparte, no es una categoría de palabras.
        RouletteBanner(onTap: () => context.go(Routes.punishments)),
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
            wordSource: WordSource.random,
            inGroups: false,
          ),
        );
    context.go(Routes.categoryIntro);
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
          const Icon(Icons.auto_awesome, size: 64, color: AppColors.yellow),
          const SizedBox(height: 12),
          Text(
            'Crea una categoría con las palabras de tu familia o tus amigos',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: onBackdrop,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '"Mi familia", "La oficina", "Viaje a Cartagena"… Se guarda solo '
            'en este celular y se juega sin internet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: onBackdrop.withValues(alpha: 0.8),
              fontSize: 15,
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
