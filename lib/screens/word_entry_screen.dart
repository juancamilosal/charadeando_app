import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/play_background.dart';

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

  /// Palabras que el grupo decidió mostrar tocando el ojo.
  final Set<Word> _revealed = {};
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
        _revealed.clear();
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
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Palabras de ${author.name}'),
          leading: BackButton(onPressed: () => context.go(Routes.config)),
        ),
        body: SafeArea(
          top: false,
          child: _handoff
              ? _HandoffView(
                  author: author.name,
                  target: target.name,
                  onReady: () => setState(() => _handoff = false),
                )
              : _entryView(context, game.config.wordsPerGroup, target.name),
        ),
      ),
    );
  }

  Widget _entryView(BuildContext context, int required, String target) {
    final enough = _words.length >= required;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Escriban palabras o frases para que $target las adivine.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PlayPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _input,
                    focusNode: _focus,
                    autofocus: true,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(
                      labelText: 'Palabra o frase',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle),
                        color: AppColors.purple,
                        onPressed: _add,
                      ),
                    ),
                  ),
                  Text(
                    '${_words.length} de $required palabras',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: enough ? AppColors.green : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _words.length,
                      itemBuilder: (context, i) {
                        final word = _words[i];
                        final visible = _revealed.contains(word);
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: IconButton(
                            icon: Icon(
                              visible ? Icons.visibility : Icons.visibility_off,
                            ),
                            color: AppColors.purple,
                            tooltip: visible ? 'Ocultar' : 'Mostrar',
                            onPressed: () => setState(
                              () => visible
                                  ? _revealed.remove(word)
                                  : _revealed.add(word),
                            ),
                          ),
                          title: Text(
                            visible
                                ? '${i + 1}. ${word.text}'
                                : 'Palabra ${i + 1}  ••••••',
                            style: visible
                                ? const TextStyle(fontWeight: FontWeight.w800)
                                : null,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Borrar',
                            onPressed: () => setState(() {
                              _revealed.remove(word);
                              _words.removeAt(i);
                            }),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Listo'),
            onPressed: enough ? _done : null,
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Icon(Icons.edit_note, size: 96, color: AppColors.yellow),
          const SizedBox(height: 12),
          Text(
            'Le toca escribir a $author',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¡Que $target no mire la pantalla!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          FilledButton(onPressed: onReady, child: const Text('Empezar')),
        ],
      ),
    );
  }
}
