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
}

/// Efectos de sonido del juego.
enum SoundEffect { tap, hit, pass, countdown, start, timeUp, spin }

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
