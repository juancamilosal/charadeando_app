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
  /// El archivo, el volumen y lo que dura cada efecto. Los que no están
  /// todavía no tienen sonido.
  static const files = {
    SoundEffect.tap: ('audio/toque.mp3', 0.6, 240),
    SoundEffect.hit: ('audio/correcto.mp3', 0.8, 1490),
    SoundEffect.pass: ('audio/paso.mp3', 0.6, 840),
    SoundEffect.countdown: ('audio/cuenta.mp3', 0.7, 550),
    SoundEffect.start: ('audio/ya.mp3', 0.7, 1100),
    SoundEffect.clock: ('audio/reloj.mp3', 0.8, 1010),
    SoundEffect.timeUp: ('audio/fin.mp3', 0.8, 2190),
    SoundEffect.spin: ('audio/ruleta.mp3', 0.9, 130),
  };

  /// Lo que dura la marimba del final del turno.
  static final timeUpLength = Duration(
    milliseconds: files[SoundEffect.timeUp]!.$3,
  );

  final _pools = <SoundEffect, Future<AudioPool>>{};

  @override
  Future<void> play(SoundEffect effect) async {
    final file = files[effect];
    if (file == null) return;
    final (asset, volume, millis) = file;
    try {
      final pool = await (_pools[effect] ??= AudioPool.create(
        source: AssetSource(asset),
        maxPlayers: 8,
        audioContext: mixedAudioContext,
        playerMode: PlayerMode.lowLatency,
      ));
      final stop = await pool.start(volume: volume);
      // Con baja latencia el reproductor no avisa cuando termina: se le
      // devuelve al grupo a mano o cada sonido dejaría uno nuevo abierto.
      Future.delayed(Duration(milliseconds: millis + 50), stop).ignore();
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
