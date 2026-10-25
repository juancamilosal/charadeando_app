import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// La configuración y los resultados se ven en vertical; el juego va en
/// horizontal. Antes del turno y durante la cuenta regresiva la pantalla
/// gira sola hacia el lado en que se tenga el celular (aunque el giro
/// automático del sistema esté apagado), así la palabra nunca queda al
/// revés; cuando empieza el juego se fija en ese lado, para que la pantalla
/// no gire al inclinar el celular.
abstract final class ScreenOrientation {
  static const _channel = MethodChannel('charadeando/pantalla');

  /// Solo Android tiene el canal. En las pruebas corren en el computador:
  /// sin canal, Flutter hace el giro.
  @visibleForTesting
  static bool native = !kIsWeb && Platform.isAndroid;

  static final _changes = StreamController<DeviceOrientation>.broadcast();

  /// Lado del juego: hacia donde está girada la pantalla ahora. Con él se
  /// orientan la vista de la cámara y el video. La inclinación se mide en
  /// el eje Z (perpendicular a la pantalla), que no cambia con el lado.
  static DeviceOrientation game = DeviceOrientation.landscapeLeft;

  /// Avisa cada vez que la pantalla gira hacia el otro lado.
  static Stream<DeviceOrientation> get changes => _changes.stream;

  static Future<void> _onCall(MethodCall call) async {
    if (call.method == 'giro') _setSide(call.arguments);
  }

  /// Toma el lado que manda Android ("izquierda" o "derecha"). Si la
  /// pantalla todavía está vertical, deja el que había.
  static void _setSide(Object? side) {
    final orientation = switch (side) {
      'izquierda' => DeviceOrientation.landscapeLeft,
      'derecha' => DeviceOrientation.landscapeRight,
      _ => null,
    };
    if (orientation == null || orientation == game) return;
    game = orientation;
    _changes.add(orientation);
  }

  static Future<void> portrait() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// Horizontal hacia cualquiera de los dos lados, siguiendo al sensor.
  static Future<void> landscape() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (native) {
      _channel.setMethodCallHandler(_onCall);
      try {
        _setSide(await _channel.invokeMethod<String>('girarLibre'));
        return;
      } on PlatformException catch (e) {
        debugPrint('[Pantalla] No se pudo girar libre: $e');
      }
    }
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Fija la pantalla en el lado en que está ahora.
  static Future<void> lock() async {
    // Sin Android se queda en el último lado conocido.
    if (native) {
      try {
        _setSide(await _channel.invokeMethod<String>('lado'));
      } on PlatformException catch (e) {
        debugPrint('[Pantalla] No se pudo leer el lado: $e');
      }
    }
    await SystemChrome.setPreferredOrientations([game]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
}
