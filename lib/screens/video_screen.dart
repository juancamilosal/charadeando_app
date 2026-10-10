import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../providers/providers.dart';

/// Reproduce el video del último turno, con opción de guardarlo en la
/// galería o compartirlo.
class VideoScreen extends ConsumerStatefulWidget {
  const VideoScreen({super.key});

  @override
  ConsumerState<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends ConsumerState<VideoScreen> {
  VideoPlayerController? _player;
  bool _saving = false;
  bool _saved = false;

  /// Por qué no se pudo reproducir el video, si falló.
  String? _error;

  String? get _path => ref.read(turnVideoProvider).path;

  @override
  void initState() {
    super.initState();
    final path = _path;
    if (path == null) {
      _error = 'No hay video de este turno.';
      return;
    }
    _open(path);
  }

  Future<void> _open(String path) async {
    final file = File(path);
    final size = await file.exists() ? await file.length() : -1;
    debugPrint('[Charadeando] Video: $path ($size bytes)');
    if (size <= 0) {
      if (mounted) setState(() => _error = 'El archivo del video no existe.');
      return;
    }
    final player = VideoPlayerController.file(file);
    _player = player;
    try {
      await player.initialize();
    } catch (e) {
      debugPrint('[Charadeando] No se pudo reproducir el video: $e');
      if (mounted) setState(() => _error = 'No se pudo reproducir el video.');
      return;
    }
    final video = player.value;
    debugPrint(
      '[Charadeando] Video listo: ${video.size.width.toInt()}x'
      '${video.size.height.toInt()}, ${video.duration.inMilliseconds} ms',
    );
    if (!mounted) return;
    await player.setLooping(true);
    await player.play();
    setState(() {});
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final path = _path;
    if (path == null) return;
    setState(() => _saving = true);
    String message;
    try {
      await ref.read(videoServiceProvider).saveToGallery(path);
      _saved = true;
      message = 'Video guardado en la galería.';
    } on GalException catch (e) {
      message = e.type == GalExceptionType.accessDenied
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

  void _togglePlay() {
    final player = _player;
    if (player == null) return;
    setState(() => player.value.isPlaying ? player.pause() : player.play());
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    final ready = player != null && player.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _togglePlay,
                child: Center(
                  child: _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : ready
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: AspectRatio(
                                aspectRatio: player.value.aspectRatio,
                                child: VideoPlayer(player),
                              ),
                            ),
                            // La barra avanza mientras el video se reproduce.
                            VideoProgressIndicator(
                              player,
                              allowScrubbing: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ],
                        )
                      : const CircularProgressIndicator(),
                ),
              ),
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
                          onPressed: _saving || _saved ? null : _save,
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
