import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../services/services.dart';

/// Cada grupo, por turnos, escribe las palabras que adivinará su rival.
/// El texto se oculta al guardarlo para que nadie vea las suyas.
class WordEntryScreen extends ConsumerStatefulWidget {
  const WordEntryScreen({super.key});

  @override
  ConsumerState<WordEntryScreen> createState() => _WordEntryScreenState();
}

class _WordEntryScreenState extends ConsumerState<WordEntryScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final List<Word> _words = [];
  int _author = 0;

  /// Pantalla intermedia para entregar el celular al siguiente grupo.
  bool _handoff = true;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final word = Word(_input.text);
    if (word.text.isEmpty) return;
    if (_words.contains(word)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esa palabra ya está en la lista.')),
      );
    } else {
      setState(() => _words.add(word));
    }
    _input.clear();
    _focus.requestFocus();
  }

  void _done() {
    final controller = ref.read(gameControllerProvider.notifier);
    controller.setWrittenWords(_author, _words);
    final groupCount = ref.read(gameControllerProvider).groups.length;
    if (_author + 1 < groupCount) {
      setState(() {
        _author++;
        _words.clear();
        _handoff = true;
      });
    } else {
      controller.start();
      context.go(Routes.turn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    final author = game.groups[_author];
    final target =
        game.groups[WordService.targetOf(_author, game.groups.length)];
    return Scaffold(
      appBar: AppBar(
        title: Text('Palabras de ${author.name}'),
        leading: BackButton(onPressed: () => context.go(Routes.config)),
      ),
      body: SafeArea(
        child: _handoff
            ? _HandoffView(
                author: author.name,
                target: target.name,
                onReady: () => setState(() => _handoff = false),
              )
            : _entryView(context, game.config.wordsPerGroup, target.name),
      ),
    );
  }

  Widget _entryView(BuildContext context, int required, String target) {
    final theme = Theme.of(context);
    final enough = _words.length >= required;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Escriban palabras o frases para que $target las adivine.',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _input,
                  focusNode: _focus,
                  autofocus: true,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    labelText: 'Palabra o frase',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: _add,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_words.length} de $required palabras',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Listo'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(200, 52),
                  ),
                  onPressed: enough ? _done : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _words.length,
              itemBuilder: (context, i) => ListTile(
                dense: true,
                leading: const Icon(Icons.visibility_off),
                title: Text('Palabra ${i + 1}  ••••••'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Borrar',
                  onPressed: () => setState(() => _words.removeAt(i)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HandoffView extends StatelessWidget {
  const _HandoffView({
    required this.author,
    required this.target,
    required this.onReady,
  });

  final String author;
  final String target;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            'Le toca escribir a $author',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('Que $target no mire la pantalla.'),
          const SizedBox(height: 24),
          FilledButton(onPressed: onReady, child: const Text('Empezar')),
        ],
      ),
    );
  }
}
