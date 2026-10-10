import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/play_background.dart';

/// Trae de Directus las palabras automáticas de toda la partida, espera a
/// que estén listas y empieza el primer turno. Durante el juego no se usa
/// internet.
class AutoWordsScreen extends ConsumerStatefulWidget {
  const AutoWordsScreen({super.key});

  /// Cuántas palabras pedir para [config]: las mismas para cada grupo.
  /// No se piden más durante la partida; si se acaban, termina.
  static int countFor(GameConfig config) =>
      config.autoWordsPerGroup * config.groupCount;

  @override
  ConsumerState<AutoWordsScreen> createState() => _AutoWordsScreenState();
}

class _AutoWordsScreenState extends ConsumerState<AutoWordsScreen> {
  bool _loading = true;
  Object? _error;

  /// Lote guardado que se usará porque no hubo internet.
  WordBatch? _offline;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final config = ref.read(gameControllerProvider).config;
    try {
      final batch = await ref
          .read(wordBankProvider)
          .load(AutoWordsScreen.countFor(config));
      if (!mounted) return;
      if (batch.words.length < config.groupCount) {
        setState(() {
          _loading = false;
          _error = 'Todavía no hay suficientes palabras en el servidor.';
        });
      } else if (batch.offline) {
        setState(() {
          _loading = false;
          _offline = batch;
        });
      } else {
        _play(batch);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  void _play(WordBatch batch) {
    ref.read(gameControllerProvider.notifier).startWithWords(batch.words);
    context.go(Routes.turn);
  }

  @override
  Widget build(BuildContext context) {
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Palabras automáticas'),
          leading: BackButton(onPressed: () => context.go(Routes.config)),
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: _content()),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 20),
          const Text(
            'Buscando palabras…',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      );
    }
    final offline = _offline;
    if (offline != null) {
      return _Message(
        icon: Icons.wifi_off,
        title: 'Sin internet',
        text:
            'Jugarán con las últimas palabras que se descargaron, así que '
            'algunas pueden repetirse.',
        action: 'Jugar',
        onAction: () => _play(offline),
      );
    }
    final error = _error;
    return _Message(
      icon: Icons.cloud_off,
      title: 'No se pudieron traer las palabras',
      text: switch (error) {
        DirectusException() => error.hint,
        String() => error,
        _ => 'Ocurrió un error inesperado.',
      },
      action: 'Reintentar',
      onAction: _load,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 56, color: AppColors.purple),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }
}
