import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../widgets/video_view.dart';

/// Reproduce el video del último turno, con opción de guardarlo en la
/// galería o compartirlo. Al guardarlo también aparece en Mis videos.
class VideoScreen extends ConsumerStatefulWidget {
  const VideoScreen({super.key});

  @override
  ConsumerState<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends ConsumerState<VideoScreen> {
  bool _saving = false;
  bool _saved = false;

  String? get _path => ref.read(turnVideoProvider).path;

  /// Los datos del turno que se guardan con el video en Mis videos.
  SavedVideo _describe(String assetId) {
    final game = ref.read(gameControllerProvider);
    final turn = game.lastTurn;
    final config = game.config;
    return SavedVideo(
      assetId: assetId,
      savedAt: DateTime.now(),
      category: config.categoryLabel,
      round: turn?.round ?? game.round,
      points: turn?.points(config.scoringMode) ?? 0,
      group: game.inGroups && turn != null
          ? game.groups[turn.groupIndex].name
          : null,
      groups: game.inGroups ? [for (final g in game.groups) g.name] : const [],
      scores: game.inGroups ? game.scores : const [],
    );
  }

  Future<void> _save() async {
    final path = _path;
    if (path == null) return;
    setState(() => _saving = true);
    String message;
    try {
      final id = await ref.read(videoGalleryProvider).save(path);
      await ref.read(myVideosProvider.notifier).add(_describe(id));
      _saved = true;
      message = 'Video guardado en la galería y en Mis videos.';
    } on GalleryException catch (e) {
      message = e.denied
          ? 'Sin permiso para guardar en la galería.'
          : 'No se pudo guardar el video.';
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _share() async {
    final path = _path;
    if (path != null) await ref.read(videoServiceProvider).share(path);
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: path == null
                  ? const Center(
                      child: Text(
                        'No hay video de este turno.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : VideoView(file: File(path)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: Icon(_saved ? Icons.check : Icons.download),
                          label: Text(_saved ? 'Guardado' : 'Guardar'),
                          onPressed: _saving || _saved || path == null
                              ? null
                              : _save,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.share),
                          label: const Text('Compartir'),
                          onPressed: _share,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
