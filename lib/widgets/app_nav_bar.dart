import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

/// Una pestaña de la barra de abajo.
typedef NavItem = (IconData icon, String label);

/// Las pestañas, en el orden de las ramas del router. Categorías va en el
/// centro y es la que se abre al iniciar.
const navItems = <NavItem>[
  (Icons.casino, 'Ruleta'),
  (Icons.groups, 'Equipos'),
  (Icons.grid_view, 'Categorías'),
  (Icons.video_library, 'Videos'),
  (Icons.settings, 'Ajustes'),
];

/// Las cinco pestañas con la barra de navegación abajo. Cada pestaña
/// conserva su estado al cambiar de una a otra.
class AppNavShell extends StatelessWidget {
  const AppNavShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: AppNavBar(
        index: shell.currentIndex,
        // Tocar la pestaña en la que se está vuelve a su pantalla inicial.
        onTap: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}

/// Barra de abajo del color del fondo elegido: la pestaña activa en el
/// color de la app (amarillo sobre los fondos oscuros, morado sobre los
/// claros) y las demás, más suaves.
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final backdrop = context.backdrop;
    final light = backdrop.light;
    final active = light ? AppColors.purple : AppColors.yellow;
    final inactive = backdrop.onColor.withValues(alpha: light ? 0.55 : 0.65);
    // En el Clásico, el color del medio del degradado.
    final gradient = backdrop.gradient;
    final color = gradient == null
        ? backdrop.color
        : Color.lerp(gradient.first, gradient.last, 0.5)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          Colors.black.withValues(alpha: light ? 0.04 : 0.18),
          color,
        ),
        border: Border(
          top: BorderSide(color: backdrop.onColor.withValues(alpha: 0.12)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < navItems.length; i++)
                Expanded(
                  child: _NavButton(
                    item: navItems[i],
                    selected: i == index,
                    activeColor: active,
                    inactiveColor: inactive,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              decoration: BoxDecoration(
                color: selected
                    ? activeColor.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.$1, color: color, size: 24),
            ),
            const SizedBox(height: 2),
            // En celulares angostos o con letra grande, se achica.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.$2,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
