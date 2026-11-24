import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/letter_words.dart';

/// Una palabra que entendió el reconocimiento de voz.
class HeardWord {
  const HeardWord(this.text, {required this.at, this.latency});

  final String text;
  final DateTime at;

  /// Cuánto tardó en aparecer desde que se empezó a hablar (aproximado:
  /// se mide con el volumen del micrófono). Null si no se pudo medir.
  final Duration? latency;
}

/// Convierte los resultados del reconocimiento (que llegan varias veces
/// mientras se habla y se van corrigiendo) en palabras nuevas, una sola
/// vez cada una. La última palabra de un resultado parcial puede cambiar
/// todavía ("pe…" → "perro"), así que se espera a que llegue otra después
/// o al resultado final.
class WordStream {
  int _taken = 0;

  /// Las palabras nuevas de [text].
  List<String> feed(String text, {required bool isFinal}) {
    final words = LetterWords.split(text);
    final stable = isFinal ? words.length : max(0, words.length - 1);
    final added = [for (var i = _taken; i < stable; i++) words[i]];
    if (stable > _taken) _taken = stable;
    if (isFinal) _taken = 0;
    return added;
  }

  /// Empieza otra frase (otra vez a escuchar).
  void reset() => _taken = 0;
}

/// Escucha sin parar con el reconocimiento de voz de Android
/// (SpeechRecognizer, por medio de speech_to_text) hasta que se llame
/// [stop]: Android corta solo tras unos segundos de silencio, y aquí se
/// vuelve a encender.
class VoiceListener extends ChangeNotifier {
  VoiceListener({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  final _stream = WordStream();
  final _words = StreamController<HeardWord>.broadcast();

  /// Las palabras nuevas, a medida que se entienden.
  Stream<HeardWord> get words => _words.stream;

  /// Lo que va entendiendo de la frase actual (todavía puede cambiar).
  String partial = '';

  /// Estado del reconocedor: listening, notListening, done…
  String status = 'sin empezar';

  /// Idioma con que escucha (es-CO, es-ES…).
  String? localeId;

  /// Pide reconocer en el celular, sin enviar el audio a internet.
  bool onDevice = true;

  /// Si se tuvo que pasar a reconocer por internet porque el celular no
  /// tenía el paquete de español.
  bool fellBackToNetwork = false;

  /// Cuántas veces se volvió a encender después de un corte.
  int restarts = 0;

  /// Tiempo sin escuchar en cada corte (de "done" a escuchar otra vez).
  final gaps = <Duration>[];

  /// Errores que reportó el reconocedor, del más viejo al más nuevo.
  final errors = <String>[];

  /// Volumen del micrófono (dB, aproximado), para ver si oye.
  double level = 0;

  bool get active => _active;
  bool _active = false;
  bool _available = false;
  bool _restartPending = false;
  DateTime? _stoppedAt;
  DateTime? _speechStart;

  /// Prepara el reconocedor y pide el permiso del micrófono. Devuelve
  /// false si el celular no tiene reconocimiento de voz.
  Future<bool> init() async {
    if (_available) return true;
    _available = await _speech.initialize(
      onStatus: _onStatus,
      onError: _onError,
    );
    if (_available) localeId = await _pickSpanish();
    notifyListeners();
    return _available;
  }

  /// El español del celular si está en español; si no, el de Colombia, y
  /// si no hay, cualquier español.
  Future<String?> _pickSpanish() async {
    final system = await _speech.systemLocale();
    if (system != null && system.localeId.toLowerCase().startsWith('es')) {
      return system.localeId;
    }
    final locales = await _speech.locales();
    String? find(String prefix) {
      for (final l in locales) {
        if (l.localeId.toLowerCase().replaceAll('_', '-').startsWith(prefix)) {
          return l.localeId;
        }
      }
      return null;
    }

    return find('es-co') ??
        find('es-419') ??
        find('es-us') ??
        find('es-mx') ??
        find('es-es') ??
        find('es') ??
        'es-CO';
  }

  /// Empieza a escuchar sin parar.
  Future<void> start() async {
    if (!await init()) return;
    _active = true;
    restarts = 0;
    gaps.clear();
    await _listen();
  }

  Future<void> _listen() async {
    if (!_active) return;
    _stream.reset();
    _speechStart = null;
    partial = '';
    try {
      await _speech.listen(
        onResult: _onResult,
        onSoundLevelChange: _onLevel,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          onDevice: onDevice,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
          localeId: localeId,
          listenFor: const Duration(minutes: 1),
          pauseFor: const Duration(seconds: 10),
        ),
      );
    } catch (e) {
      errors.add('listen: $e');
    }
    final stopped = _stoppedAt;
    if (stopped != null) {
      gaps.add(DateTime.now().difference(stopped));
      _stoppedAt = null;
    }
    notifyListeners();
  }

  /// Deja de escuchar.
  Future<void> stop() async {
    _active = false;
    await _speech.stop();
    status = 'parado';
    notifyListeners();
  }

  void _onResult(SpeechRecognitionResult result) {
    partial = result.recognizedWords;
    final now = DateTime.now();
    for (final word in _stream.feed(
      result.recognizedWords,
      isFinal: result.finalResult,
    )) {
      final start = _speechStart;
      _words.add(
        HeardWord(
          word,
          at: now,
          latency: start == null ? null : now.difference(start),
        ),
      );
      _speechStart = null;
    }
    notifyListeners();
  }

  /// Volumen del micrófono: cuando sube después de un silencio, se anota
  /// como el momento en que se empezó a hablar.
  void _onLevel(double value) {
    level = value;
    if (value >= 3 && _speechStart == null) _speechStart = DateTime.now();
    notifyListeners();
  }

  void _onStatus(String value) {
    status = value;
    if ((value == SpeechToText.doneStatus ||
            value == SpeechToText.notListeningStatus) &&
        _active) {
      _stoppedAt ??= DateTime.now();
      _restartSoon();
    }
    notifyListeners();
  }

  void _onError(SpeechRecognitionError error) {
    errors.add(error.errorMsg);
    // Sin el paquete de español en el celular, escucha por internet.
    if (onDevice &&
        (error.errorMsg.contains('language') ||
            error.errorMsg.contains('server') && error.permanent)) {
      onDevice = false;
      fellBackToNetwork = true;
    }
    if (_active) {
      _stoppedAt ??= DateTime.now();
      _restartSoon();
    }
    notifyListeners();
  }

  void _restartSoon() {
    if (_restartPending) return;
    _restartPending = true;
    // Un momento para que Android libere el reconocedor (si no, error_busy).
    Timer(const Duration(milliseconds: 150), () async {
      _restartPending = false;
      if (!_active || _speech.isListening) return;
      restarts++;
      await _listen();
    });
  }

  @override
  void dispose() {
    _active = false;
    _speech.cancel();
    _words.close();
    super.dispose();
  }
}
