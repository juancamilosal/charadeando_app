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
/// El texto se oculta al guardarlo para que nadie vea las suyas. Sin grupos
/// se muestra una sola vez: todos escriben una lista de al menos
/// [GameConfig.minSoloWords] palabras.
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

  /// Pantalla intermedia para entregar el celular al siguiente grupo. Sin
  /// grupos no hace falta.
  late bool _handoff = ref.read(gameControllerProvider).config.inGroups;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Palabras que caben en la lista, o null si no hay tope. Solo la
  /// partida rápida tiene tope.
  int? get _max => ref.read(gameControllerProvider).config.quick
      ? GameConfig.quickMaxWords
      : null;

  bool get _full {
    final max = _max;
    return max != null && _words.length >= max;
  }

  void _add() {
    final word = Word(_input.text);
    if (word.text.isEmpty || _full) return;
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

  /// Volver: la partida rápida no pasó por la configuración.
  void _back() {
    final quick = ref.read(gameControllerProvider).config.quick;
    context.go(quick ? Routes.freeMode : Routes.config);
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    if (!game.config.inGroups) return _soloView(context);
    final author = game.groups[_author];
    final rivals = WordService.rivalsLabel(_author, game.groups);
    final single = game.groups.length == 2;
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Palabras de ${author.name}'),
          leading: BackButton(onPressed: _back),
        ),
        body: SafeArea(
          top: false,
          child: _handoff
              ? _HandoffView(
                  author: author.name,
                  rivals: rivals,
                  single: single,
                  onReady: () => setState(() => _handoff = false),
                )
              : _entryView(
                  context,
                  game.config.wordsPerGroup,
                  message: single
                      ? 'Escriban palabras o frases para que $rivals las '
                            'adivine.'
                      : 'Escriban palabras o frases para $rivals. Ustedes no '
                            'las verán en su turno.',
                  counter:
                      '${_words.length} de ${game.config.wordsPerGroup} '
                      'palabras',
                ),
        ),
      ),
    );
  }

  /// Sin grupos: una sola lista con las palabras de todos. En la partida
  /// rápida, de [GameConfig.minSoloWords] a [GameConfig.quickMaxWords], con
  /// un contador y una barra de avance.
  Widget _soloView(BuildContext context) {
    final max = _max;
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Palabras'),
          leading: BackButton(onPressed: _back),
        ),
        body: SafeArea(
          top: false,
          child: _entryView(
            context,
            GameConfig.minSoloWords,
            message: max != null
                ? 'Escriban de ${GameConfig.minSoloWords} a $max palabras o '
                      'frases.'
                : 'Escriban las palabras o frases que van a jugar. Mínimo '
                      '${GameConfig.minSoloWords}.',
            counter: max != null
                ? '${_words.length} de $max'
                : '${_words.length} '
                      '${_words.length == 1 ? 'palabra' : 'palabras'} · '
                      'mínimo ${GameConfig.minSoloWords}',
            max: max,
          ),
        ),
      ),
    );
  }

  Widget _entryView(
    BuildContext context,
    int required, {
    required String message,
    required String counter,
    int? max,
  }) {
    final enough = _words.length >= required;
    final full = _full;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: TextStyle(
              color: context.onBackdrop,
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
                    enabled: !full,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(
                      labelText: full ? 'Lista completa' : 'Palabra o frase',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle),
                        color: AppColors.purple,
                        onPressed: full ? null : _add,
                      ),
                    ),
                  ),
                  if (max != null)
                    _QuickCounter(
                      counter: counter,
                      count: _words.length,
                      max: max,
                      enough: enough,
                    )
                  else
                    Text(
                      counter,
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
            icon: Icon(max != null ? Icons.arrow_forward : Icons.check),
            label: Text(max != null ? 'Continuar' : 'Listo'),
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
    required this.rivals,
    required this.single,
    required this.onReady,
  });

  final String author;
  final String rivals;

  /// Verdadero si hay un solo grupo rival.
  final bool single;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Spacer(),
          Icon(Icons.edit_note, size: 96, color: AppColors.yellow),
          SizedBox(height: 12),
          Text(
            'Le toca escribir a $author',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: context.onBackdrop,
            ),
          ),
          SizedBox(height: 8),
          Text(
            single
                ? '¡Que $rivals no mire la pantalla!'
                : '¡Que $rivals no miren la pantalla!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.onBackdrop,
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

/// Contador de la partida rápida: "12 de 20" con una barra de avance y,
/// desde el mínimo, "Ya pueden jugar" en verde.
class _QuickCounter extends StatelessWidget {
  const _QuickCounter({
    required this.counter,
    required this.count,
    required this.max,
    required this.enough,
  });

  final String counter;
  final int count;
  final int max;
  final bool enough;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              counter,
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 8),
            if (enough)
              const Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppColors.green,
                        size: 18,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Ya pueden jugar',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: count / max,
            minHeight: 10,
            color: enough ? AppColors.green : AppColors.orange,
            backgroundColor: const Color(0xFFEDE6F8),
          ),
        ),
      ],
    );
  }
}
