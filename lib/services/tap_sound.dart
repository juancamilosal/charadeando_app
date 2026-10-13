import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'background_music.dart';

/// Lo que necesita el sonido de los toques de un reproductor.
abstract interface class TapSoundPlayer {
  Future<void> play();
}

/// El sonido corto de los botones (`assets/audio/toque.mp3`). Usa varios
/// reproductores para que los toques seguidos no se corten.
class AssetTapSoundPlayer implements TapSoundPlayer {
  static const asset = 'audio/toque.mp3';
  static const volume = 0.6;

  Future<AudioPool>? _pool;

  Future<AudioPool> _ready() => _pool ??= AudioPool.create(
    source: AssetSource(asset),
    maxPlayers: 3,
    audioContext: mixedAudioContext,
    playerMode: PlayerMode.lowLatency,
  );

  @override
  Future<void> play() async {
    try {
      await (await _ready()).start(volume: volume);
    } on Object catch (e) {
      debugPrint('[Toques] No se pudo reproducir: $e');
      _pool = null;
    }
  }
}

/// No suena: para las pruebas.
class SilentTapSoundPlayer implements TapSoundPlayer {
  @override
  Future<void> play() async {}
}

/// El reproductor de verdad, o uno mudo en las pruebas.
TapSoundPlayer defaultTapSoundPlayer() =>
    Platform.environment.containsKey('FLUTTER_TEST')
    ? SilentTapSoundPlayer()
    : AssetTapSoundPlayer();
