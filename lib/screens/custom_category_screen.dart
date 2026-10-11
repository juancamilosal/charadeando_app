import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/category_card.dart';
import '../widgets/config_section.dart';
import '../widgets/play_background.dart';

/// Crear o editar una categoría propia: nombre, descripción, color, ícono y
/// palabras, con la vista previa de su tarjeta.
class CustomCategoryScreen extends ConsumerStatefulWidget {
  const CustomCategoryScreen({super.key, this.category});

  /// La categoría que se edita, o null para crear una nueva.
  final CustomCategory? category;

  @override
  ConsumerState<CustomCategoryScreen> createState() =>
      _CustomCategoryScreenState();
}

class _CustomCategoryScreenState extends ConsumerState<CustomCategoryScreen> {
  late final _name = TextEditingController(text: widget.category?.name);
  late final _description = TextEditingController(
    text: widget.category?.description,
  );
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  late int _colorIndex = widget.category?.colorIndex ?? 0;
  late String _iconKey = widget.category?.iconKey ?? 'family';
  late List<String> _words = [...?widget.category?.words];
  bool _showErrors = false;
  bool _changed = false;

  bool get _editing => widget.category != null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  CustomCategory get _draft => CustomCategory(
    id: widget.category?.id ?? CustomCategoriesController.newId(),
    name: _name.text.trim(),
    description: _description.text.trim(),
    colorIndex: _colorIndex,
    iconKey: _iconKey,
    words: _words,
  );

  void _touch(VoidCallback change) => setState(() {
    change();
    _changed = true;
  });

  /// Agrega lo que se escribió o pegó: una palabra o varias separadas por
  /// comas o saltos de línea. Las repetidas no se agregan.
  void _addWords() {
    final incoming = CustomWords.parse(_input.text);
    if (incoming.isEmpty) return;
    final result = CustomWords.add(_words, incoming);
    _touch(() {
      _words = result.words;
      _input.clear();
    });
    _inputFocus.requestFocus();
    if (result.repeated.isNotEmpty) {
      final list = result.repeated.take(3).join(', ');
      final more = result.repeated.length > 3 ? '…' : '';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Ya estaban: $list$more')));
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    // Lo que quedó escrito sin tocar "Agregar" también cuenta.
    if (_input.text.trim().isNotEmpty) _addWords();
    await ref.read(customCategoriesProvider.notifier).save(_draft);
    if (mounted) context.pop();
  }

  Future<void> _leave() async {
    if (!_changed) {
      context.pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Se perderán los cambios de esta categoría.'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.purple),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: PlayBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(_editing ? 'Editar categoría' : 'Nueva categoría'),
            leading: BackButton(onPressed: _leave),
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                // Vista previa de la tarjeta, del tamaño de la cuadrícula.
                LayoutBuilder(
                  builder: (context, box) {
                    final width = (box.maxWidth - 14) / 2;
                    return Center(
                      child: SizedBox(
                        width: width,
                        height: width / 0.7,
                        child: CategoryCard.custom(draft),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                ConfigSection(
                  icon: Icons.badge,
                  title: 'Nombre',
                  children: [
                    TextField(
                      key: const ValueKey('nombre'),
                      controller: _name,
                      maxLength: CustomCategory.maxNameLength,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => _touch(() {}),
                      decoration: InputDecoration(
                        hintText: 'Ej: Mi familia',
                        errorText: _showErrors && _name.text.trim().isEmpty
                            ? 'Escribe un nombre'
                            : null,
                      ),
                    ),
                    TextField(
                      key: const ValueKey('descripcion'),
                      controller: _description,
                      maxLength: CustomCategory.maxDescriptionLength,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => _touch(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Descripción corta (opcional)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ConfigSection(
                  icon: Icons.palette,
                  title: 'Color',
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var i = 0; i < CustomCategory.colors.length; i++)
                          _ColorDot(
                            color: CustomCategory.colors[i],
                            selected: i == _colorIndex,
                            onTap: () => _touch(() => _colorIndex = i),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ConfigSection(
                  icon: Icons.emoji_symbols,
                  title: 'Ícono',
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in CustomCategory.icons.entries)
                          _IconChoice(
                            icon: entry.value,
                            color: draft.color,
                            selected: entry.key == _iconKey,
                            onTap: () => _touch(() => _iconKey = entry.key),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _wordsSection(draft),
                // Una palabra por renglón sobre el fondo, la última agregada
                // arriba.
                if (_words.isNotEmpty) const SizedBox(height: 10),
                for (final w in _words.reversed)
                  _WordRow(
                    word: w,
                    onDelete: () => _touch(
                      () => _words = [
                        for (final x in _words)
                          if (x != w) x,
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: Text(_editing ? 'Guardar cambios' : 'Crear categoría'),
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _wordsSection(CustomCategory draft) {
    const hint = TextStyle(fontSize: 13, color: Color(0xFF6B5A86));
    final missing = draft.missingWords;
    return ConfigSection(
      icon: Icons.edit_note,
      title: 'Palabras · ${_words.length}',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('palabras'),
                controller: _input,
                focusNode: _inputFocus,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addWords(),
                decoration: const InputDecoration(
                  hintText: 'Escribe una palabra o pega varias',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Agregar',
              style: IconButton.styleFrom(backgroundColor: AppColors.purple),
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: _addWords,
            ),
          ],
        ),
        const Text(
          'Puedes pegar varias separadas por comas o en renglones distintos.',
          style: hint,
        ),
        Text(
          missing > 0
              ? 'Te ${missing == 1 ? 'falta 1 palabra' : 'faltan $missing palabras'} '
                    'para poder jugar (mínimo ${CustomCategory.minWords}).'
              : '¡Lista para jugar!',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: missing > 0 ? AppColors.coral : AppColors.green,
          ),
        ),
        const Text(
          'Con ${CustomCategory.suggestedWords} o más palabras no se repiten '
          'tan rápido.',
          style: hint,
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.ink : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 22)
            : null,
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFFF4EEFF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: selected ? Colors.white : AppColors.ink),
      ),
    );
  }
}

/// Un renglón de la lista de palabras, en blanco sobre el fondo de
/// colores, con su botón para borrarla. La palabra se ve completa: si es
/// muy larga, sigue en el renglón de abajo.
class _WordRow extends StatelessWidget {
  const _WordRow({required this.word, required this.onDelete});

  final String word;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, top: 4, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              word,
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Borrar "$word"',
            icon: const Icon(Icons.close, size: 30, color: Colors.white),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
