import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

/// Abre desde abajo los castigos de la ruleta para cambiarlos, borrarlos o
/// agregar los propios, hasta [RouletteSetup.maxFields]. Devuelve la lista
/// nueva, o null si cierran sin guardar.
Future<List<String>?> showPunishmentEditor(
  BuildContext context,
  List<String> punishments,
) => showModalBottomSheet<List<String>>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => PunishmentEditor(punishments: punishments),
);

/// Los castigos de la ruleta, uno por campo, para editarlos antes de girar.
class PunishmentEditor extends StatefulWidget {
  const PunishmentEditor({super.key, required this.punishments});

  final List<String> punishments;

  @override
  State<PunishmentEditor> createState() => _PunishmentEditorState();
}

class _PunishmentEditorState extends State<PunishmentEditor> {
  late final List<TextEditingController> _controllers = [
    for (final p in widget.punishments.take(RouletteSetup.maxFields))
      TextEditingController(text: p),
  ];

  /// El campo recién agregado, para escribir en él de una vez.
  TextEditingController? _added;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _full => _controllers.length >= RouletteSetup.maxFields;
  bool get _atMin => _controllers.length <= RouletteSetup.minFields;

  void _add() => setState(() {
    _added = TextEditingController();
    _controllers.add(_added!);
    _error = null;
  });

  void _remove(int i) => setState(() {
    _controllers.removeAt(i).dispose();
    _error = null;
  });

  /// Guarda los que tienen texto; los vacíos se quitan.
  void _save() {
    final punishments = [
      for (final c in _controllers)
        if (c.text.trim().isNotEmpty) c.text.trim(),
    ];
    if (punishments.length < RouletteSetup.minFields) {
      setState(
        () => _error =
            'La ruleta necesita al menos ${RouletteSetup.minFields} castigos.',
      );
      return;
    }
    Navigator.pop(context, punishments);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Que el teclado no tape los campos.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3D7F7),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Castigos de la ruleta',
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cambien los que quieran o agreguen los suyos, hasta '
              '${RouletteSetup.maxFields}.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B5A86)),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _controllers.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  key: ValueKey(_controllers[i]),
                  controller: _controllers[i],
                  autofocus: _controllers[i] == _added,
                  maxLength: 60,
                  // Los largos se ven completos, en varias líneas.
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Castigo ${i + 1}',
                    counterText: '',
                    suffixIcon: IconButton(
                      tooltip: 'Quitar castigo ${i + 1}',
                      icon: const Icon(Icons.close),
                      onPressed: _atMin ? null : () => _remove(i),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.purple),
              icon: const Icon(Icons.add_circle_outline),
              label: Text(
                _full
                    ? 'Ya tiene ${RouletteSetup.maxFields} castigos'
                    : 'Agregar castigo '
                          '(${_controllers.length} de ${RouletteSetup.maxFields})',
              ),
              onPressed: _full ? null : _add,
            ),
            if (_error != null)
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
              ),
              onPressed: _save,
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
