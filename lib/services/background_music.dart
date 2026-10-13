import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Lo que necesita la música de fondo de un reproductor.
abstract interface class MusicPlayer {
  Future<void> play();
  Future<void> pause();
  Future<void> dispose();
}

/// Reproduce en bucle la música de la app (`assets/audio/musica.mp3`).
class AssetMusicPlayer implements MusicPlayer {
  static const asset = 'audio/musica.mp3';

  /// Bajita, para que acompañe sin tapar a los jugadores.
  static const volume = 0.35;

  AudioPlayer? _player;

  Future<AudioPlayer> _ready() async {
    final current = _player;
    if (current != null) return current;
    final player = _player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.loop);
    await player.setVolume(volume);
    await player.setSource(AssetSource(asset));
    return player;
  }

  @override
  Future<void> play() async {
    try {
      await (await _ready()).resume();
    } on Object catch (e) {
      debugPrint('[Música] No se pudo reproducir: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player?.pause();
    } on Object catch (e) {
      debugPrint('[Música] No se pudo pausar: $e');
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _player?.dispose();
    } on Object catch (_) {}
    _player = null;
  }
}

/// No suena: para las pruebas, donde no hay reproductor de audio.
class SilentMusicPlayer implements MusicPlayer {
  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() async {}
}

/// El reproductor de verdad, o uno mudo en las pruebas.
MusicPlayer defaultMusicPlayer() =>
    Platform.environment.containsKey('FLUTTER_TEST')
    ? SilentMusicPlayer()
    : AssetMusicPlayer();

/// Música de fondo de la app. Suena mientras el ajuste "Música" esté
/// encendido, la app esté a la vista y ninguna pantalla la haya silenciado
/// (el turno y los videos, que tienen su propio sonido).
class BackgroundMusic {
  BackgroundMusic(this._player);

  final MusicPlayer _player;

  bool _enabled = false;
  bool _foreground = true;
  int _holds = 0;
  bool _playing = false;

  /// Si está sonando.
  bool get playing => _playing;

  /// El ajuste "Música".
  set enabled(bool value) {
    _enabled = value;
    _sync();
  }

  /// Falso cuando la app pasa a segundo plano.
  set foreground(bool value) {
    _foreground = value;
    _sync();
  }

  /// Una pantalla pide silencio mientras está abierta; [release] lo
  /// devuelve.
  void hold() {
    _holds++;
    _sync();
  }

  void release() {
    if (_holds > 0) _holds--;
    _sync();
  }

  void _sync() {
    final play = _enabled && _foreground && _holds == 0;
    if (play == _playing) return;
    _playing = play;
    (play ? _player.play() : _player.pause()).ignore();
  }

  void dispose() => _player.dispose().ignore();
}
