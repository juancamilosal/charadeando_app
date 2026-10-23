import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Lo que la app necesita de Google Play para actualizarse sola.
abstract class AppUpdater {
  /// Verdadero si Play tiene una versión nueva que se puede bajar en
  /// segundo plano mientras se juega.
  Future<bool> updateAvailable();

  /// Verdadero si la versión nueva ya está bajada y solo falta reiniciar.
  Future<bool> alreadyDownloaded();

  /// Muestra el aviso de Google Play ("Actualizar" / "No, gracias") y, si
  /// aceptan, baja la versión nueva en segundo plano. Verdadero si
  /// aceptaron.
  Future<bool> startDownload();

  /// Avisa cuando la versión nueva terminó de bajar.
  Stream<void> get downloaded;

  /// Instala la versión bajada; la app se reinicia.
  Future<void> install();
}

/// Actualizaciones dentro de la app de Google Play (solo Android, solo en
/// versiones de la tienda: en modo debug o instalada a mano no hace nada).
class PlayAppUpdater implements AppUpdater {
  bool get _supported => !kDebugMode && Platform.isAndroid;

  @override
  Future<bool> updateAvailable() async {
    if (!_supported) return false;
    try {
      final info = await InAppUpdate.checkForUpdate();
      return info.updateAvailability == UpdateAvailability.updateAvailable &&
          info.flexibleUpdateAllowed;
    } on Object catch (e) {
      // Sin Play Store o instalada por fuera de la tienda.
      debugPrint('[Actualización] No se pudo consultar: $e');
      return false;
    }
  }

  @override
  Future<bool> alreadyDownloaded() async {
    if (!_supported) return false;
    try {
      final info = await InAppUpdate.checkForUpdate();
      return info.installStatus == InstallStatus.downloaded;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> startDownload() async {
    try {
      return await InAppUpdate.startFlexibleUpdate() == AppUpdateResult.success;
    } on Object catch (e) {
      debugPrint('[Actualización] No se pudo bajar: $e');
      return false;
    }
  }

  @override
  Stream<void> get downloaded => !_supported
      ? const Stream.empty()
      : InAppUpdate.installUpdateListener
            .where((status) => status == InstallStatus.downloaded)
            .map((_) {})
            .handleError((Object _) {});

  @override
  Future<void> install() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } on Object catch (e) {
      debugPrint('[Actualización] No se pudo instalar: $e');
    }
  }
}

/// Busca actualizaciones al abrir la app (y al volver a ella, como mucho
/// una vez por hora). Si hay una, Google Play pregunta si actualizar y la
/// baja mientras se sigue jugando; cuando está lista, [ready] se vuelve
/// verdadero para que la app ofrezca "Reiniciar".
class AppUpdateController {
  AppUpdateController(this._updater, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppUpdater _updater;
  final DateTime Function() _clock;

  /// La versión nueva ya se bajó: falta reiniciar para usarla.
  final ready = ValueNotifier<bool>(false);

  DateTime? _lastCheck;
  bool _asked = false;
  StreamSubscription<void>? _sub;

  static const _every = Duration(hours: 1);

  /// Consulta a Play si hay algo nuevo. Se pregunta al jugador una sola vez
  /// por sesión: si dice "No, gracias", no se insiste hasta volver a abrir.
  Future<void> check() async {
    final now = _clock();
    final last = _lastCheck;
    if (last != null && now.difference(last) < _every) return;
    _lastCheck = now;
    if (ready.value) return;
    if (await _updater.alreadyDownloaded()) {
      ready.value = true;
      return;
    }
    if (_asked || !await _updater.updateAvailable()) return;
    _asked = true;
    _sub ??= _updater.downloaded.listen((_) => ready.value = true);
    await _updater.startDownload();
  }

  /// Instala la versión nueva (la app se reinicia).
  Future<void> install() => _updater.install();

  void dispose() {
    _sub?.cancel();
    ready.dispose();
  }
}
