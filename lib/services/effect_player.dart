import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'background_music.dart';
import 'feedback_services.dart';

/// Lo que necesitan los efectos de sonido de un reproductor.
abstract interface class EffectPlayer {
  Future<void> play(SoundEffect effect);
}

/// Reproduce los efectos que ya tienen archivo en `assets/audio/`. Cada uno
/// usa varios reproductores para que los seguidos no se corten.
class AssetEffectPlayer implements EffectPlayer {
  /// El archivo y el volumen de cada efecto. Los que no están todavía no
  /// tienen sonido.
  static const files = {
    SoundEffect.tap: ('audio/toque.mp3', 0.6),
    SoundEffect.hit: ('audio/correcto.mp3', 0.8),
    SoundEffect.pass: ('audio/paso.mp3', 0.6),
    SoundEffect.countdown: ('audio/cuenta.mp3', 0.7),
    SoundEffect.start: ('audio/ya.mp3', 0.7),
    SoundEffect.clock: ('audio/reloj.mp3', 0.8),
    SoundEffect.timeUp: ('audio/fin.mp3', 0.8),
  };

  final _pools = <SoundEffect, Future<AudioPool>>{};

  @override
  Future<void> play(SoundEffect effect) async {
    final file = files[effect];
    if (file == null) return;
    final (asset, volume) = file;
    try {
      final pool = await (_pools[effect] ??= AudioPool.create(
        source: AssetSource(asset),
        maxPlayers: 3,
        audioContext: mixedAudioContext,
        playerMode: PlayerMode.lowLatency,
      ));
      await pool.start(volume: volume);
    } on Object catch (e) {
      debugPrint('[Efectos] No se pudo reproducir $effect: $e');
      _pools.remove(effect);
    }
  }
}

/// No suena: para las pruebas.
class SilentEffectPlayer implements EffectPlayer {
  @override
  Future<void> play(SoundEffect effect) async {}
}

/// El reproductor de verdad, o uno mudo en las pruebas.
EffectPlayer defaultEffectPlayer() =>
    Platform.environment.containsKey('FLUTTER_TEST')
    ? SilentEffectPlayer()
    : AssetEffectPlayer();
