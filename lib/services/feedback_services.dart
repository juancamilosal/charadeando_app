import 'package:flutter/services.dart';

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
enum SoundEffect { hit, pass, countdown, timeUp, spin }

/// Efectos de sonido. La app todavía no trae efectos: este servicio ya
/// respeta el ajuste "Efectos de sonido" para cuando se agreguen los
/// archivos. La música de fondo va aparte (`BackgroundMusic`).
class SoundService {
  const SoundService({required this.music, required this.effects});

  final bool music;
  final bool effects;

  /// Reproduce [effect] si los efectos están encendidos. Devuelve si sonó
  /// (todavía nunca, porque no hay archivos).
  Future<bool> play(SoundEffect effect) async {
    if (!effects) return false;
    // Aquí se reproducirá el archivo del efecto.
    return false;
  }
}
