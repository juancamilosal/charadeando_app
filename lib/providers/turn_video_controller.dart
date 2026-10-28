import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'providers.dart';
import '../services/error_reporter.dart';
import '../services/video_gallery.dart';

enum TurnVideoStatus { none, rendering, ready }

/// Video del último turno, que se arma mientras se ven los resultados.
class TurnVideoState {
  const TurnVideoState(
    this.status, {
    this.path,
    this.progress = 0,
    this.withWords = true,
    this.saved = false,
  });

  static const none = TurnVideoState(TurnVideoStatus.none);

  final TurnVideoStatus status;
  final String? path;

  /// Avance del armado, de 0 a 1.
  final double progress;

  /// Falso si no se pudieron escribir las palabras y se usa el video tal
  /// como se grabó.
  final bool withWords;

  /// Ya se guardó en la galería y en Mis videos.
  final bool saved;

  /// Listo y sin guardar: si se sale, se pierde.
  bool get unsaved => status == TurnVideoStatus.ready && path != null && !saved;
}

class TurnVideoController extends Notifier<TurnVideoState> {
  /// Cambia cada vez que se descarta un video, para ignorar el resultado de
  /// un armado que ya no sirve.
  int _generation = 0;

  /// Hay un video armándose que se guarda solo al terminar ("Guardar
  /// automáticamente"): al salir del resultado no se cancela ni se borra.
  bool _savingInBackground = false;

  /// Los datos del turno del video actual, tomados al terminar el turno.
  SavedVideo Function(String assetId)? _describe;

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
    final describe = _describe = _describeTurn();
    final autoSave = ref.read(settingsProvider).autoSaveVideo;
    state = const TurnVideoState(TurnVideoStatus.rendering);
    final videos = ref.read(videoServiceProvider);
    final dir = await videos.directory();
    final output =
        '${dir.path}/charadeando_${DateTime.now().millisecondsSinceEpoch}.mp4';
    String path;
    var withWords = true;
    if (autoSave) _savingInBackground = true;
    try {
      await ref
          .read(videoRendererProvider)
          .render(
            recording,
            workDir: dir,
            outputPath: output,
            bitrateMbps: _bitrate(resolution),
            // Premium quita la marca de agua.
            watermark: !ref.read(premiumUnlockedProvider),
            onProgress: (progress) {
              if (generation != _generation) return;
              state = TurnVideoState(
                TurnVideoStatus.rendering,
                progress: progress,
              );
            },
          );
      if (generation != _generation && !autoSave) {
        await _deleteIfExists(output);
        return;
      }
      for (final segment in recording.segments) {
        await videos.delete(segment);
      }
      path = output;
    } on Exception catch (e, stack) {
      if (generation != _generation && !autoSave) return;
      ErrorReporter.instance.report(
        e,
        stack,
        reason: 'Armar el video (FFmpeg)',
      );
      // Sin palabras, al menos queda la primera parte tal como se grabó.
      await _deleteIfExists(output);
      path = recording.segments.first;
      withWords = false;
    }
    final current = generation == _generation;
    if (current) {
      state = TurnVideoState(
        TurnVideoStatus.ready,
        path: path,
        withWords: withWords,
      );
    }
    if (!autoSave) return;
    // "Guardar automáticamente": se guarda aunque ya hayan salido del
    // resultado; si ya salieron, el archivo se borra después de guardarlo.
    if (current) {
      await save();
    } else {
      await _store(path, describe);
      await _deleteIfExists(path);
    }
    _savingInBackground = false;
  }

  /// Guarda el video en la galería y en Mis videos, con los datos del turno.
  /// Devuelve el mensaje para mostrar.
  Future<String> save() async {
    final video = state;
    final path = video.path;
    final describe = _describe ?? _describeTurn();
    if (path == null) return 'No hay video para guardar.';
    if (video.saved) return 'El video ya está guardado.';
    try {
      await _store(path, describe, quiet: false);
      if (state.path == path) {
        state = TurnVideoState(
          video.status,
          path: path,
          withWords: video.withWords,
          saved: true,
        );
      }
      return 'Video guardado en la galería y en Mis videos.';
    } on GalleryException catch (e) {
      return e.denied
          ? 'Sin permiso para guardar en la galería.'
          : 'No se pudo guardar el video.';
    }
  }

  /// Copia el video a la galería y lo anota en Mis videos. Con [quiet],
  /// los errores solo se reportan (se guardaba por detrás).
  Future<void> _store(
    String path,
    SavedVideo Function(String assetId) describe, {
    bool quiet = true,
  }) async {
    try {
      final id = await ref.read(videoGalleryProvider).save(path);
      await ref.read(myVideosProvider.notifier).add(describe(id));
    } on GalleryException catch (e, stack) {
      if (!quiet) rethrow;
      ErrorReporter.instance.report(e, stack, reason: 'Guardar solo el video');
    }
  }

  /// Los datos del último turno para Mis videos.
  SavedVideo Function(String assetId) _describeTurn() {
    final game = ref.read(gameControllerProvider);
    final turn = game.lastTurn;
    final config = game.config;
    final category = config.categoryLabel;
    final round = turn?.round ?? game.round;
    final points = turn?.points(config.scoringMode) ?? 0;
    final group = game.inGroups && turn != null
        ? game.groups[turn.groupIndex].name
        : null;
    final groups = game.inGroups
        ? [for (final g in game.groups) g.name]
        : const <String>[];
    final scores = game.inGroups ? game.scores : const <int>[];
    return (assetId) => SavedVideo(
      assetId: assetId,
      savedAt: DateTime.now(),
      category: category,
      round: round,
      points: points,
      group: group,
      groups: groups,
      scores: scores,
    );
  }

  /// Detiene el armado y borra todos los videos del turno.
  Future<void> discard() async {
    _generation++;
    state = TurnVideoState.none;
    // Con "Guardar automáticamente" el armado sigue por detrás y borra sus
    // propios archivos al terminar.
    if (_savingInBackground) return;
    await ref.read(videoRendererProvider).cancel();
    await ref.read(videoServiceProvider).deleteAll();
  }

  static int _bitrate(VideoResolution resolution) => switch (resolution) {
    VideoResolution.off || VideoResolution.normal => 3,
    VideoResolution.hd => 6,
    VideoResolution.fullHd => 10,
    VideoResolution.max => 16,
  };

  static Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
