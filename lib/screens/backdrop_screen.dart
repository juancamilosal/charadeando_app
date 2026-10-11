import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets/play_background.dart';

/// "Fondos": el usuario elige el color de fondo de la app y, con él, el
/// estilo de las tarjetas. Se guarda en el celular y cambia al instante.
class BackdropScreen extends ConsumerWidget {
  const BackdropScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(backdropProvider);
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Fondos'),
          leading: BackButton(
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(Routes.categories),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Text(
                'Elige el fondo de la app. Se guarda en este celular.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.onBackdrop,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.82,
                children: [
                  for (final backdrop in Backdrop.values)
                    _BackdropTile(
                      backdrop: backdrop,
                      selected: backdrop == selected,
                      onTap: () =>
                          ref.read(backdropProvider.notifier).select(backdrop),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una opción: el fondo con dos tarjetas de muestra en su estilo y su
/// nombre. La elegida lleva un borde grueso y un chulo.
class _BackdropTile extends StatelessWidget {
  const _BackdropTile({
    required this.backdrop,
    required this.selected,
    required this.onTap,
  });

  final Backdrop backdrop;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mark = context.backdrop.light ? AppColors.ink : AppColors.yellow;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Fondo ${backdrop.label}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: backdrop.color,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? mark : Colors.white,
              width: selected ? 5 : 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _MiniCard(
                            color: AppColors.green,
                            style: backdrop.cards,
                            light: backdrop.light,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MiniCard(
                            color: AppColors.indigo,
                            style: backdrop.cards,
                            light: backdrop.light,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    backdrop.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: backdrop.onColor,
                    ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppColors.green,
                      size: 28,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de categoría en miniatura, con el estilo del fondo.
class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.color,
    required this.style,
    required this.light,
  });

  final Color color;
  final CardStyle style;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final (fill, border, shadow) = switch (style) {
      CardStyle.sticker => (
        color,
        Colors.white,
        BoxShadow(
          color: light ? const Color(0x33000000) : const Color(0x66000000),
          offset: const Offset(0, 3),
        ),
      ),
      CardStyle.comic => (
        color,
        AppColors.ink,
        const BoxShadow(color: AppColors.ink, offset: Offset(2, 3)),
      ),
      CardStyle.white => (
        Colors.white,
        color,
        const BoxShadow(color: Color(0x22000000), blurRadius: 4),
      ),
    };
    final ink = style == CardStyle.white ? color : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 2),
        boxShadow: [shadow],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Center(
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Container(
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}
