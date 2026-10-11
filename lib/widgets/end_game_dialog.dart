import 'package:flutter/material.dart';

import '../theme.dart';

/// Pregunta antes de finalizar la partida. [played] dice si ya se jugó
/// algún turno: si no, no hay puntajes que mostrar y se vuelve al inicio.
Future<bool> confirmEndGame(
  BuildContext context, {
  required bool played,
}) async {
  final end = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Finalizar el juego?'),
      content: Text(
        played
            ? 'La partida termina aquí y se muestran los puntajes hasta ahora.'
            : 'Todavía no se ha jugado ningún turno: vuelven al inicio.',
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.purple),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Seguir jugando'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Finalizar'),
        ),
      ],
    ),
  );
  return end ?? false;
}

/// Botón "Finalizar juego", blanco para ir sobre el fondo de colores.
/// [compact] lo hace bajito, para pantallas donde el espacio es justo.
class EndGameButton extends StatelessWidget {
  const EndGameButton({
    super.key,
    required this.onPressed,
    this.compact = false,
  });

  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: Icon(Icons.flag, size: compact ? 18 : null),
      label: const Text('Finalizar juego'),
      style: compact
          ? TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
      onPressed: onPressed,
    );
  }
}
