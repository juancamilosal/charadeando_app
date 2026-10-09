import 'dart:io';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeVideoService extends VideoService {
  final deleted = <String>[];
  var deletedAll = false;

  @override
  Future<Directory> directory() async => Directory.systemTemp;

  @override
  Future<void> delete(String path) async => deleted.add(path);

  @override
  Future<void> deleteAll() async => deletedAll = true;
}

class FakeRenderer extends VideoRenderer {
  FakeRenderer({this.fail = false});

  final bool fail;
  final finish = <void Function()>[];
  var cancelled = false;

  @override
  Future<String> render(
    TurnRecording recording, {
    required Directory workDir,
    required String outputPath,
    required int bitrateMbps,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);
    if (fail) throw const VideoRenderException('prueba');
    return outputPath;
  }

  @override
  Future<void> cancel() async => cancelled = true;
}

const recording = TurnRecording(
  segments: ['/v/parte1.mp4', '/v/parte2.mp4'],
  captions: [],
  duration: Duration(seconds: 10),
);

void main() {
  late FakeVideoService videos;

  ProviderContainer container(FakeRenderer renderer) {
    videos = FakeVideoService();
    final c = ProviderContainer(
      overrides: [
        videoServiceProvider.overrideWithValue(videos),
        videoRendererProvider.overrideWithValue(renderer),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('queda listo con las palabras y borra las partes', () async {
    final c = container(FakeRenderer());
    await c
        .read(turnVideoProvider.notifier)
        .process(recording, VideoResolution.hd);
    final state = c.read(turnVideoProvider);
    expect(state.status, TurnVideoStatus.ready);
    expect(state.withWords, isTrue);
    expect(state.path, contains('charadeando_'));
    expect(videos.deleted, recording.segments);
  });

  test('si falla, usa la primera parte sin palabras', () async {
    final c = container(FakeRenderer(fail: true));
    await c
        .read(turnVideoProvider.notifier)
        .process(recording, VideoResolution.hd);
    final state = c.read(turnVideoProvider);
    expect(state.status, TurnVideoStatus.ready);
    expect(state.withWords, isFalse);
    expect(state.path, '/v/parte1.mp4');
  });

  test('sin partes grabadas no hay video', () async {
    final c = container(FakeRenderer());
    await c
        .read(turnVideoProvider.notifier)
        .process(
          const TurnRecording(
            segments: [],
            captions: [],
            duration: Duration.zero,
          ),
          VideoResolution.hd,
        );
    expect(c.read(turnVideoProvider).status, TurnVideoStatus.none);
  });

  test('descartar cancela el armado y borra los videos', () async {
    final renderer = FakeRenderer();
    final c = container(renderer);
    final processing = c
        .read(turnVideoProvider.notifier)
        .process(recording, VideoResolution.hd);
    await c.read(turnVideoProvider.notifier).discard();
    await processing;
    expect(renderer.cancelled, isTrue);
    expect(videos.deletedAll, isTrue);
    expect(c.read(turnVideoProvider).status, TurnVideoStatus.none);
  });
}
