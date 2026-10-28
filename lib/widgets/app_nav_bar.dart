import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

/// Una pestaña de la barra de abajo: su ícono (con el color y el tamaño) y
/// su nombre.
typedef NavItem = (
  Widget Function(Color color, double size) icon,
  String label,
);

Widget Function(Color, double) _material(IconData icon) =>
    (color, size) => Icon(icon, color: color, size: size);

/// Las pestañas, en el orden de las ramas del router. Categorías va en el
/// centro y es la que se abre al iniciar.
final navItems = <NavItem>[
  ((color, size) => RouletteIcon(color: color, size: size), 'Ruleta'),
  (_material(Icons.groups_rounded), 'Equipos'),
  (_material(Icons.grid_view_rounded), 'Categorías'),
  (_material(Icons.videocam_rounded), 'Videos'),
  (_material(Icons.settings_rounded), 'Ajustes'),
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

  /// Con el fondo Noche la barra es oscura.
  static const darkActive = Color(0xFFB794FF);
  static const darkInactive = Color(0xFF8D84C2);

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CurvedBarPainter(context.surfaces.card),
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

/// El fondo de la barra (blanco, u oscuro con Noche): el borde de arriba es
/// un arco que sube en el centro.
class _CurvedBarPainter extends CustomPainter {
  const _CurvedBarPainter(this.color);

  final Color color;

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
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CurvedBarPainter oldDelegate) =>
      oldDelegate.color != color;
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
    final dark = context.backdrop.dark;
    final color = selected
        ? (dark ? AppNavBar.darkActive : AppNavBar.active)
        : (dark ? AppNavBar.darkInactive : AppNavBar.inactive);
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
              child: item.$1(color, 32),
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

/// Ícono de una ruleta: la rueda dividida en campos, con su centro y el
/// indicador arriba. Material no trae uno.
class RouletteIcon extends StatelessWidget {
  const RouletteIcon({super.key, required this.color, this.size = 24});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RouletteIconPainter(color, context.surfaces.card),
      ),
    );
  }
}

class _RouletteIconPainter extends CustomPainter {
  const _RouletteIconPainter(this.color, this.background);

  final Color color;

  /// El color de la barra, para los campos vacíos y los bordes.
  final Color background;

  static const _fields = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s / 2, s * 0.55);
    final radius = s * 0.4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = 2 * pi / _fields;
    for (var i = 0; i < _fields; i++) {
      canvas.drawArc(
        rect,
        -pi / 2 + i * sweep,
        sweep,
        true,
        Paint()..color = i.isEven ? color : background,
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.07,
    );
    canvas.drawCircle(center, s * 0.08, Paint()..color = background);
    canvas.drawCircle(center, s * 0.04, Paint()..color = color);
    // El indicador, arriba, apuntando a la rueda.
    final top = center.dy - radius;
    final pointer = Path()
      ..moveTo(center.dx - s * 0.11, top - s * 0.11)
      ..lineTo(center.dx + s * 0.11, top - s * 0.11)
      ..lineTo(center.dx, top + s * 0.08)
      ..close();
    canvas.drawPath(
      pointer,
      Paint()
        ..color = background
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.06
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(pointer, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RouletteIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.background != background;
}
