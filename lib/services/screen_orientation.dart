import 'package:flutter/services.dart';

/// La configuración y los resultados se ven en vertical; solo el juego,
/// desde la cuenta regresiva hasta que se acaba el tiempo, va en horizontal.
abstract final class ScreenOrientation {
  /// Orientación del juego. Es una sola para que el video siempre quede
  /// grabado en la misma dirección que se ve la pantalla.
  static const game = DeviceOrientation.landscapeLeft;

  static Future<void> portrait() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  static Future<void> landscape() async {
    await SystemChrome.setPreferredOrientations([game]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
}
