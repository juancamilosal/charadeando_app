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

  /// Le pregunta al sistema, en este momento, si hay un televisor
  /// conectado. Null si la plataforma no lo dice (por ejemplo, en pruebas).
  /// Sirve para no fiarse de un aviso viejo: algunos celulares no avisan
  /// cuando dejan de duplicar la pantalla.
  Future<bool?> isConnected() async {
    try {
      return await _methods.invokeMethod<bool>('conectado');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Abre la lista de televisores del sistema. Devuelve falso si el sistema
  /// no tiene una pantalla para eso (en iPhone se usa el Centro de control).
  Future<bool> openSettings() => _call('abrirAjustes');

  /// Deja de duplicar la pantalla, o abre la pantalla del sistema donde se
  /// detiene. Devuelve falso si no pudo hacer ninguna de las dos (en iPhone
  /// se detiene desde el Centro de control).
  Future<bool> disconnect() => _call('desconectar');

  Future<bool> _call(String method) async {
    try {
      return await _methods.invokeMethod<bool>(method) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
