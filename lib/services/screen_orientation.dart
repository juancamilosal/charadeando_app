import 'package:flutter/services.dart';

/// La configuración y los resultados se ven en vertical; solo el juego,
/// desde la cuenta regresiva hasta que se acaba el tiempo, va en horizontal.
abstract final class ScreenOrientation {
  /// Ajuste "Rotación invertida": el juego gira hacia el otro lado. Lo fija
  /// el controlador de los ajustes al abrir la app y al cambiarlo.
  static bool inverted = false;

  /// Orientación del juego. Es una sola para que el video siempre quede
  /// grabado en la misma dirección que se ve la pantalla. La inclinación
  /// se mide en el eje Z (perpendicular a la pantalla), que no cambia al
  /// girar hacia un lado o hacia el otro.
  static DeviceOrientation get game => inverted
      ? DeviceOrientation.landscapeRight
      : DeviceOrientation.landscapeLeft;

  static Future<void> portrait() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  static Future<void> landscape() async {
    await SystemChrome.setPreferredOrientations([game]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
}
