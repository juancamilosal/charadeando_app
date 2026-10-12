import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

/// Una pestaña de la barra de abajo.
typedef NavItem = (IconData icon, String label);

/// Las pestañas, en el orden de las ramas del router. Categorías va en el
/// centro y es la que se abre al iniciar.
const navItems = <NavItem>[
  (Icons.casino_rounded, 'Ruleta'),
  (Icons.groups_rounded, 'Equipos'),
  (Icons.grid_view_rounded, 'Categorías'),
  (Icons.videocam_rounded, 'Videos'),
  (Icons.settings_rounded, 'Ajustes'),
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

/// Barra de abajo blanca, con el borde de arriba curvo y una sombra
/// suave. La pestaña activa va en morado y las demás, en lila claro; así se
/// ve igual con todos los fondos.
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.index, required this.onTap});

  /// Cuánto sube el centro del borde curvo.
  static const curve = 12.0;

  static const active = AppColors.purple;
  static const inactive = Color(0xFFB4B1E6);

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _CurvedBarPainter(),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SizedBox(
            height: 70,
            child: Row(
              children: [
                for (var i = 0; i < navItems.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: navItems[i],
                      selected: i == index,
                      onTap: () => onTap(i),
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

/// El fondo blanco de la barra: el borde de arriba es un arco que sube en
/// el centro.
class _CurvedBarPainter extends CustomPainter {
  const _CurvedBarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const c = AppNavBar.curve;
    // El arco sube por encima de la barra, sobre la pantalla.
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(size.width / 2, -2 * c, size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawShadow(path, const Color(0x552B0A57), 8, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_CurvedBarPainter oldDelegate) => false;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppNavBar.active : AppNavBar.inactive;
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 40,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.1 : 1,
              duration: const Duration(milliseconds: 200),
              child: Icon(item.$1, color: color, size: 32),
            ),
            const SizedBox(height: 4),
            // En celulares angostos o con letra grande, se achica.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.$2,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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
