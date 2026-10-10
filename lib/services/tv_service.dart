import 'dart:async';

import 'package:flutter/services.dart';

/// Conexión con el televisor del Modo TV.
///
/// La app no transmite nada por su cuenta: el celular se duplica en el
/// televisor con AirPlay, Chromecast o un cable HDMI, y lo que se ve en el
/// celular se ve en el TV. Este servicio solo pregunta al sistema si hay una
/// pantalla externa conectada (código nativo en `MainActivity.kt` y
/// `TvDisplayPlugin.swift`) y abre la lista de televisores cuando el sistema
/// lo permite.
class TvService {
  static const _methods = MethodChannel('charadeando/tv');
  static const _events = EventChannel('charadeando/tv/conexion');

  /// Emite si hay un televisor conectado: el estado actual al escuchar y
  /// después cada cambio. Si la plataforma no lo soporta, emite falso.
  Stream<bool> connection() async* {
    try {
      yield* _events.receiveBroadcastStream().map((value) => value == true);
    } on MissingPluginException {
      yield false;
    }
  }

  /// Abre la lista de televisores del sistema. Devuelve falso si el sistema
  /// no tiene una pantalla para eso (en iPhone se usa el Centro de control).
  Future<bool> openSettings() async {
    try {
      return await _methods.invokeMethod<bool>('abrirAjustes') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
