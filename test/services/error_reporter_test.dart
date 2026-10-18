import 'package:charadeando_app/services/crash_reporting.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackend implements CrashBackend {
  _FakeBackend({this.fail = false});

  final bool fail;
  final errors = <(String, bool)>[];
  final keys = <String, Object>{};
  bool? enabled;

  @override
  Future<void> setEnabled(bool on) async => enabled = on;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    required String reason,
    required bool fatal,
  }) async {
    if (fail) throw StateError('Crashlytics falló');
    errors.add((reason, fatal));
  }

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details) async =>
      errors.add(('Flutter', true));

  @override
  Future<void> setKey(String key, Object value) async => keys[key] = value;
}

void main() {
  test('sin Firebase solo cuenta los errores', () {
    final reporter = ErrorReporter();
    reporter.report(Exception('cámara'), null, reason: 'Abrir la cámara');
    reporter.setKey(CrashKeys.screen, '/turno');
    expect(reporter.errorCount, 1);
  });

  test('los errores manejados van como no fatales y los demás como '
      'fatales', () {
    final backend = _FakeBackend();
    final reporter = ErrorReporter()..attach(backend);
    reporter.report(Exception('ffmpeg'), null, reason: 'Armar el video');
    reporter.reportFatal(StateError('sin atrapar'), StackTrace.current);
    reporter.reportFlutterError(
      FlutterErrorDetails(exception: Exception('layout')),
    );
    expect(backend.errors, [
      ('Armar el video', false),
      ('Error sin atrapar', true),
      ('Flutter', true),
    ]);
    expect(reporter.errorCount, 3);
  });

  test('las claves y el interruptor llegan a Crashlytics', () async {
    final backend = _FakeBackend();
    final reporter = ErrorReporter()..attach(backend);
    reporter
      ..setKey(CrashKeys.gameMode, 'fotomimica')
      ..setKey(CrashKeys.recording, true);
    await reporter.setEnabled(false);
    await Future<void>.delayed(Duration.zero);
    expect(backend.keys, {'modo_juego': 'fotomimica', 'grabando': true});
    expect(backend.enabled, isFalse);
  });

  test('si Crashlytics falla, reportar no causa otro error', () async {
    final reporter = ErrorReporter()..attach(_FakeBackend(fail: true));
    reporter.report(Exception('x'), null, reason: 'Prueba');
    await Future<void>.delayed(Duration.zero);
    expect(reporter.errorCount, 1);
  });

  test('en modo debug nunca se envían reportes, aunque el ajuste esté '
      'encendido', () {
    // Las pruebas corren en modo debug.
    expect(kDebugMode, isTrue);
    expect(crashReportsAllowed(true), isFalse);
    expect(crashReportsAllowed(false), isFalse);
  });
}
