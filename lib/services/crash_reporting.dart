import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'error_reporter.dart';

/// Conecta Firebase Crashlytics, solo en Android por ahora. Los errores de
/// Flutter y los asíncronos que nadie atrapó se reportan como fatales.
///
/// Si falta `android/app/google-services.json` (está fuera del repositorio,
/// ver README.md), Firebase no arranca: la app funciona igual y solo cuenta
/// los errores. En modo debug nunca se envía nada, para que las pruebas no
/// ensucien los informes; [enabled] es el ajuste "Enviar reportes y
/// estadísticas anónimas".
Future<void> startCrashReporting({required bool enabled}) async {
  final reporter = ErrorReporter.instance;
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reporter.reportFlutterError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[Errores] Sin atrapar: $error\n$stack');
    reporter.reportFatal(error, stack);
    return true;
  };
  if (!Platform.isAndroid) return;
  try {
    await Firebase.initializeApp();
  } on Object catch (e) {
    debugPrint(
      '[Errores] Firebase no arrancó (¿falta google-services.json?): $e',
    );
    return;
  }
  reporter.attach(_Crashlytics(FirebaseCrashlytics.instance));
  await reporter.setEnabled(enabled);
}

/// Si se envían reportes: nunca en modo debug.
bool crashReportsAllowed(bool setting) => setting && !kDebugMode;

class _Crashlytics implements CrashBackend {
  _Crashlytics(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> setEnabled(bool enabled) => _crashlytics
      .setCrashlyticsCollectionEnabled(crashReportsAllowed(enabled));

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    required String reason,
    required bool fatal,
  }) => _crashlytics.recordError(error, stack, reason: reason, fatal: fatal);

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details) =>
      _crashlytics.recordFlutterFatalError(details);

  @override
  Future<void> setKey(String key, Object value) =>
      _crashlytics.setCustomKey(key, value);
}
