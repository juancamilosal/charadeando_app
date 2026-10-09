import 'package:flutter/material.dart';

/// Grupo de opciones donde solo se elige una. Las opciones no disponibles
/// se muestran deshabilitadas con una etiqueta que explica por qué.
class OptionSelector<T> extends StatelessWidget {
  const OptionSelector({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.lockReasonOf,
    this.description,
  });

  final String label;
  final List<T> options;
  final T selected;
  final String Function(T option) labelOf;

  /// Devuelve por qué la opción está bloqueada, o null si se puede elegir.
  final String? Function(T option)? lockReasonOf;
  final String? description;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              _chip(option, lockReasonOf?.call(option)),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(description!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }

  Widget _chip(T option, String? lockReason) {
    final locked = lockReason != null;
    return ChoiceChip(
      label: Text(
        locked ? '${labelOf(option)} · $lockReason' : labelOf(option),
      ),
      avatar: locked ? const Icon(Icons.lock_outline, size: 18) : null,
      selected: option == selected,
      onSelected: locked ? null : (_) => onSelected(option),
    );
  }
}
