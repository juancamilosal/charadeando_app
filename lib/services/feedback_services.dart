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

/// Música y efectos de sonido. La app todavía no trae sonidos: este
/// servicio ya respeta los ajustes "Música" y "Efectos de sonido" para
/// cuando se agreguen los archivos.
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

  /// Empieza la música de fondo si está encendida.
  Future<bool> startMusic() async {
    if (!music) return false;
    return false;
  }
}
