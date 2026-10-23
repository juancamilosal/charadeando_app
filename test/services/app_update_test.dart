import 'dart:async';

import 'package:charadeando_app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Google Play de mentira: dice si hay versión nueva y cuenta lo que se le
/// pide.
class _FakeUpdater implements AppUpdater {
  bool available = false;
  bool downloadedBefore = false;
  int checks = 0;
  int downloads = 0;
  int installs = 0;
  final _downloaded = StreamController<void>.broadcast();

  void finishDownload() => _downloaded.add(null);

  @override
  Future<bool> updateAvailable() async {
    checks++;
    return available;
  }

  @override
  Future<bool> alreadyDownloaded() async => downloadedBefore;

  @override
  Future<bool> startDownload() async {
    downloads++;
    return true;
  }

  @override
  Stream<void> get downloaded => _downloaded.stream;

  @override
  Future<void> install() async => installs++;
}

void main() {
  test('sin versión nueva no pregunta nada', () async {
    final play = _FakeUpdater();
    final updates = AppUpdateController(play);
    await updates.check();
    expect(play.downloads, 0);
    expect(updates.ready.value, isFalse);
  });

  test('con versión nueva la baja y avisa cuando está lista', () async {
    final play = _FakeUpdater()..available = true;
    final updates = AppUpdateController(play);
    await updates.check();
    expect(play.downloads, 1);
    expect(updates.ready.value, isFalse);
    play.finishDownload();
    await Future<void>.delayed(Duration.zero);
    expect(updates.ready.value, isTrue);
    await updates.install();
    expect(play.installs, 1);
  });

  test('si ya estaba bajada, solo falta reiniciar', () async {
    final play = _FakeUpdater()..downloadedBefore = true;
    final updates = AppUpdateController(play);
    await updates.check();
    expect(updates.ready.value, isTrue);
    expect(play.downloads, 0);
  });

  test('pregunta una sola vez y busca como mucho una vez por hora', () async {
    final play = _FakeUpdater()..available = true;
    var now = DateTime(2026, 10, 23, 9);
    final updates = AppUpdateController(play, clock: () => now);
    await updates.check();
    // Volver a la app al rato no vuelve a consultar.
    now = now.add(const Duration(minutes: 20));
    await updates.check();
    expect(play.checks, 1);
    // Una hora después consulta, pero no vuelve a preguntar.
    now = now.add(const Duration(hours: 1));
    await updates.check();
    expect(play.checks, 1);
    expect(play.downloads, 1);
  });
}
