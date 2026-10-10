import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/play_background.dart';

/// Pantalla de prueba: pide 20 palabras al azar a la colección de Directus,
/// o le pide a Gemini 20 nuevas (que quedan guardadas) si [gemini] es
/// verdadero. Muestra cada una con su categoría, o el error y la respuesta
/// del servidor si algo falla.
class DirectusTestScreen extends ConsumerStatefulWidget {
  const DirectusTestScreen({super.key, this.gemini = false});

  final bool gemini;

  @override
  ConsumerState<DirectusTestScreen> createState() => _DirectusTestScreenState();
}

class _DirectusTestScreenState extends ConsumerState<DirectusTestScreen> {
  late Future<List<RemoteWord>> _words;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final directus = ref.read(directusServiceProvider);
    _words = widget.gemini
        ? directus.createWords(20)
        : directus.fetchWords(count: 20);
  }

  @override
  Widget build(BuildContext context) {
    final directus = ref.read(directusServiceProvider);
    final url = widget.gemini ? directus.createUri : directus.wordsUri;
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(widget.gemini ? 'Probar Gemini' : 'Probar Directus'),
          leading: BackButton(onPressed: () => context.go(Routes.welcome)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Volver a consultar',
              onPressed: () => setState(_load),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: FutureBuilder<List<RemoteWord>>(
            future: _words,
            builder: (context, snapshot) {
              final header = _UrlCard(url: 'POST $url');
              if (snapshot.connectionState != ConnectionState.done) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    header,
                    const SizedBox(height: 40),
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ],
                );
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    header,
                    const SizedBox(height: 16),
                    _ErrorCard(error: snapshot.error!),
                  ],
                );
              }
              final words = snapshot.data!;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  header,
                  const SizedBox(height: 16),
                  Text(
                    words.isEmpty
                        ? 'La colección está vacía.'
                        : '${words.length} '
                              '${words.length == 1 ? 'palabra' : 'palabras'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final word in words) ...[
                    _WordCard(word: word),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _UrlCard extends StatelessWidget {
  const _UrlCard({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Consulta', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          SelectableText(url, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.word});

  final RemoteWord word;

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.turquoise.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              word.categoria,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0E8A7C),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              word.frase,
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final (int? status, String? hint, String? body) = switch (error) {
      DirectusException(:final statusCode, :final hint, :final body) => (
        statusCode,
        hint,
        body,
      ),
      _ => (null, null, null),
    };
    final known = hint != null;
    return PlayPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.coral),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  !known
                      ? 'Error'
                      : status == null
                      ? 'Sin respuesta'
                      : 'Error $status',
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hint ?? 'Ocurrió un error inesperado.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SelectableText(
            body ?? '$error',
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
