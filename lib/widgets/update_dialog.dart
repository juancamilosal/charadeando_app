import 'package:flutter/material.dart';

import '../theme.dart';

/// La versión nueva de Charadeando ya se bajó: se ofrece actualizar.
/// Responde verdadero si tocaron "Actualizar".
Future<bool> showUpdateReady(BuildContext context) async {
  final update = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(
        Icons.system_update_rounded,
        size: 44,
        color: AppColors.purple,
      ),
      title: const Text('¡Hay una versión nueva!'),
      content: const Text(
        'Ya está lista la nueva versión de Charadeando, con mejoras y '
        'arreglos. Al actualizar, la app se cierra y se abre de nuevo.',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.purple),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Más tarde'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Actualizar'),
        ),
      ],
    ),
  );
  return update ?? false;
}
