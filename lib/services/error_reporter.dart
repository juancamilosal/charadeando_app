import 'package:flutter/foundation.dart';

/// Lo que hace falta de Firebase Crashlytics. Así este archivo no depende de
/// Firebase y en las pruebas no hay nada que enviar.
abstract interface class CrashBackend {
  Future<void> setEnabled(bool enabled);
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    required String reason,
    required bool fatal,
  });
  Future<void> recordFlutterError(FlutterErrorDetails details);
  Future<void> setKey(String key, Object value);
}

/// Claves que acompañan cada reporte, sin datos personales.
abstract final class CrashKeys {
  /// Ruta de la pantalla actual ("/turno").
  static const screen = 'pantalla';

  /// normal, fotomimica, tv o juez.
  static const gameMode = 'modo_juego';

  /// Si la cámara está grabando el turno.
  static const recording = 'grabando';

  /// Resolución del video elegida ("hd").
  static const resolution = 'resolucion';
}

/// Reporta errores a Firebase Crashlytics, si está conectado (ver
/// `crash_reporting.dart`). Se usa desde cualquier parte con
/// [ErrorReporter.instance], también desde servicios que no tienen `ref`.
///
/// Los errores que la app ya maneja y le muestra al usuario (la cámara, el
/// video, las compras, el servidor) se reportan como no fatales con
/// [report], para verlos en la consola sin cerrar nada.
class ErrorReporter {
  ErrorReporter();

  /// El de la app.
  static final instance = ErrorReporter();

  CrashBackend? _backend;

  /// Errores reportados desde que abrió la app (fatales o no). La reseña
  /// no se pide si hubo alguno durante la partida.
  int get errorCount => _errorCount;
  int _errorCount = 0;

  /// Conecta Crashlytics.
  void attach(CrashBackend backend) => _backend = backend;

  /// Enciende o apaga el envío ("Enviar datos anónimos").
  Future<void> setEnabled(bool enabled) async {
    try {
      await _backend?.setEnabled(enabled);
    } on Object catch (e) {
      debugPrint('[Errores] No se pudo cambiar el envío: $e');
    }
  }

  /// Un error que la app ya manejó: se reporta como no fatal. [reason] dice
  /// dónde pasó ("Cámara", "Video del turno").
  void report(Object error, StackTrace? stack, {required String reason}) {
    _record(error, stack, reason: reason, fatal: false);
  }

  /// Un error que nadie atrapó (Flutter o asíncrono): fatal.
  void reportFatal(Object error, StackTrace? stack) {
    _record(error, stack, reason: 'Error sin atrapar', fatal: true);
  }

  void reportFlutterError(FlutterErrorDetails details) {
    _errorCount++;
    _send(() => _backend?.recordFlutterError(details));
  }

  /// Una clave para los próximos reportes.
  void setKey(String key, Object value) {
    _send(() => _backend?.setKey(key, value));
  }

  void _record(
    Object error,
    StackTrace? stack, {
    required String reason,
    required bool fatal,
  }) {
    _errorCount++;
    debugPrint('[Errores] $reason: $error');
    _send(
      () => _backend?.recordError(
        error,
        stack ?? StackTrace.current,
        reason: reason,
        fatal: fatal,
      ),
    );
  }

  /// Nunca deja que reportar un error cause otro.
  void _send(Future<void>? Function() call) {
    try {
      call()?.catchError((Object e) {
        debugPrint('[Errores] No se pudo reportar: $e');
      });
    } on Object catch (e) {
      debugPrint('[Errores] No se pudo reportar: $e');
    }
  }
}
