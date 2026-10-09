import 'package:flutter/material.dart';

import '../theme.dart';

/// Sección de la configuración: tarjeta blanca con ícono, título y una
/// línea que la separa del contenido.
class ConfigSection extends StatelessWidget {
  const ConfigSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: [
                Icon(icon, color: AppColors.purple),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEDE7F6)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de la configuración: la etiqueta a la izquierda y el control a la
/// derecha.
class ConfigRow extends StatelessWidget {
  const ConfigRow({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;

  /// Explicación corta debajo de la etiqueta.
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              if (hint != null)
                Text(
                  hint!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B5A86),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        child,
      ],
    );
  }
}
