import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'providers.dart';

enum TurnVideoStatus { none, rendering, ready }

/// Video del último turno, que se arma mientras se ven los resultados.
class TurnVideoState {
  const TurnVideoState(
    this.status, {
    this.path,
    this.progress = 0,
    this.withWords = true,
  });

  static const none = TurnVideoState(TurnVideoStatus.none);

  final TurnVideoStatus status;
  final String? path;

  /// Avance del armado, de 0 a 1.
  final double progress;

  /// Falso si no se pudieron escribir las palabras y se usa el video tal
  /// como se grabó.
  final bool withWords;
}

class TurnVideoController extends Notifier<TurnVideoState> {
  /// Cambia cada vez que se descarta un video, para ignorar el resultado de
  /// un armado que ya no sirve.
  int _generation = 0;

  @override
  TurnVideoState build() => TurnVideoState.none;

  Future<void> process(
    TurnRecording recording,
    VideoResolution resolution,
  ) async {
    final generation = ++_generation;
    if (recording.isEmpty) {
      state = TurnVideoState.none;
      return;
    }
    state = const TurnVideoState(TurnVideoStatus.rendering);
    final videos = ref.read(videoServiceProvider);
    final dir = await videos.directory();
    final output =
        '${dir.path}/charadeando_${DateTime.now().millisecondsSinceEpoch}.mp4';
    try {
      await ref
          .read(videoRendererProvider)
          .render(
            recording,
            workDir: dir,
            outputPath: output,
            bitrateMbps: _bitrate(resolution),
            onProgress: (progress) {
              if (generation != _generation) return;
              state = TurnVideoState(
                TurnVideoStatus.rendering,
                progress: progress,
              );
            },
          );
      if (generation != _generation) {
        await _deleteIfExists(output);
        return;
      }
      for (final segment in recording.segments) {
        await videos.delete(segment);
      }
      state = TurnVideoState(TurnVideoStatus.ready, path: output);
    } on Exception {
      if (generation != _generation) return;
      // Sin palabras, al menos queda la primera parte tal como se grabó.
      await _deleteIfExists(output);
      state = TurnVideoState(
        TurnVideoStatus.ready,
        path: recording.segments.first,
        withWords: false,
      );
    }
  }

  /// Detiene el armado y borra todos los videos del turno.
  Future<void> discard() async {
    _generation++;
    state = TurnVideoState.none;
    await ref.read(videoRendererProvider).cancel();
    await ref.read(videoServiceProvider).deleteAll();
  }

  static int _bitrate(VideoResolution resolution) => switch (resolution) {
    VideoResolution.normal => 3,
    VideoResolution.hd => 6,
    VideoResolution.fullHd => 10,
    VideoResolution.max => 16,
  };

  static Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
