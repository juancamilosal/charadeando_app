import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Reproduce un video en bucle, con su barra de avance. Al tocarlo se pausa
/// o sigue.
class VideoView extends StatefulWidget {
  const VideoView({super.key, required this.file});

  /// El video, o null si todavía no se tiene o no existe.
  final File? file;

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  VideoPlayerController? _player;

  /// Por qué no se pudo reproducir el video, si falló.
  String? _error;

  @override
  void initState() {
    super.initState();
    final file = widget.file;
    if (file == null) {
      _error = 'El archivo del video no existe.';
    } else {
      _open(file);
    }
  }

  Future<void> _open(File file) async {
    final size = await file.exists() ? await file.length() : -1;
    debugPrint('[Charadeando] Video: ${file.path} ($size bytes)');
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

  void _togglePlay() {
    final player = _player;
    if (player == null) return;
    setState(() => player.value.isPlaying ? player.pause() : player.play());
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    final ready = player != null && player.value.isInitialized;
    return GestureDetector(
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
    );
  }
}
