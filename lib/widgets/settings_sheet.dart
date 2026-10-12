import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme.dart';

/// Una opción del menú de configuración.
class SettingsOption {
  const SettingsOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.route,
  });

  final IconData icon;

  /// Color del cuadro del ícono.
  final Color color;
  final String title;
  final String description;

  /// Pantalla que abre.
  final String route;
}

/// Las opciones del menú, en orden. Para agregar más (sonido, vibración,
/// premium, privacidad), basta con sumarlas aquí.
const settingsOptions = [
  SettingsOption(
    icon: Icons.palette,
    color: AppColors.magenta,
    title: 'Fondos',
    description: 'Cambia el color de la app',
    route: Routes.backdrops,
  ),
  SettingsOption(
    icon: Icons.help_outline,
    color: AppColors.blue,
    title: 'Cómo se juega',
    description: 'Ver la explicación otra vez',
    route: Routes.welcome,
  ),
];

/// Abre el menú de configuración desde abajo, del color del fondo elegido.
Future<void> showSettingsMenu(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const SettingsSheet(),
  );
}

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final backdrop = context.backdrop;
    final on = backdrop.onColor;
    final gradient = backdrop.gradient;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backdrop.color,
        gradient: gradient == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: on.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
                child: Text(
                  'Configuración',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: on,
                  ),
                ),
              ),
              for (final option in settingsOptions)
                _OptionRow(
                  option: option,
                  onTap: () {
                    final router = GoRouter.of(context);
                    Navigator.pop(context);
                    router.push(option.route);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una fila: el ícono en un cuadro de color, el nombre, la descripción y
/// una flecha.
class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.onTap});

  final SettingsOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = context.onBackdrop;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: option.color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(option.icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: on,
                    ),
                  ),
                  Text(
                    option.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: on.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: on),
          ],
        ),
      ),
    );
  }
}
