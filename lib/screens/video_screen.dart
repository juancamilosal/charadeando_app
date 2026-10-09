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

  String? get _path => ref.read(gameControllerProvider).lastTurn?.videoPath;

  @override
  void initState() {
    super.initState();
    final path = _path;
    if (path == null) return;
    final player = VideoPlayerController.file(File(path));
    _player = player;
    player.initialize().then((_) {
      if (!mounted) return;
      player
        ..setLooping(true)
        ..play();
      setState(() {});
    });
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
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _togglePlay,
                child: Center(
                  child: ready
                      ? AspectRatio(
                          aspectRatio: player.value.aspectRatio,
                          child: VideoPlayer(player),
                        )
                      : const CircularProgressIndicator(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    icon: Icon(_saved ? Icons.check : Icons.download),
                    label: Text(_saved ? 'Guardado' : 'Guardar'),
                    onPressed: _saving || _saved ? null : _save,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.share),
                    label: const Text('Compartir'),
                    onPressed: _share,
                  ),
                  const SizedBox(height: 12),
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
