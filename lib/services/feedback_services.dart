import 'package:flutter/services.dart';

import 'effect_player.dart';

/// Todas las vibraciones de la app pasan por aquí, para respetar el ajuste
/// "Vibración".
class Haptics {
  const Haptics({required this.enabled});

  final bool enabled;

  Future<void> heavy() async {
    if (enabled) await HapticFeedback.heavyImpact();
  }

  Future<void> light() async {
    if (enabled) await HapticFeedback.lightImpact();
  }

  Future<void> selection() async {
    if (enabled) await HapticFeedback.selectionClick();
  }

  Future<void> vibrate() async {
    if (enabled) await HapticFeedback.vibrate();
  }

  static const _channel = MethodChannel('charadeando/vibrar');

  /// Una vibración de [length] con fuerza [strength] (0 a 1). Si el
  /// celular no la soporta (o fuera de Android), un toque fuerte.
  Future<void> buzz(Duration length, {double strength = 1}) =>
      pattern([(length, strength)]);

  /// Varias vibraciones seguidas: cada una con su largo y su fuerza (0 a
  /// 1); con fuerza 0, es una pausa.
  Future<void> pattern(List<(Duration, double)> steps) async {
    if (!enabled || steps.isEmpty) return;
    try {
      final done = await _channel.invokeMethod<bool>('vibrar', {
        'tiempos': [for (final (length, _) in steps) length.inMilliseconds],
        'fuerzas': [
          for (final (_, strength) in steps)
            (strength.clamp(0.0, 1.0) * 255).round(),
        ],
      });
      if (done == true) return;
    } on MissingPluginException {
      // Fuera de Android (o en las pruebas).
    } on PlatformException {
      // Sin vibrador o sin permiso.
    }
    await HapticFeedback.heavyImpact();
  }
}

/// Efectos de sonido del juego.
enum SoundEffect {
  tap,
  hit,
  pass,
  countdown,
  start,
  clock,
  timeUp,
  spin,

  /// El tic de la bomba de Letras.
  tick,

  /// La explosión de la bomba de Letras.
  boom,
}

/// Efectos de sonido, según el ajuste "Efectos de sonido". Suenan los que ya
/// tienen archivo (`AssetEffectPlayer.files`): el toque de los botones y el
/// "¡Correcto!" del turno. La música de fondo va aparte (`BackgroundMusic`).
class SoundService {
  const SoundService({required this.effects, required this.player});

  final bool effects;
  final EffectPlayer player;

  /// Reproduce [effect] si los efectos están encendidos. Devuelve si lo pidió.
  bool play(SoundEffect effect) {
    if (!effects) return false;
    player.play(effect).ignore();
    return true;
  }
}
