import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../models/letter_words.dart';

/// Diccionario de español de "Letras", dentro de la app (no usa internet):
/// unas 500.000 palabras, con plurales, femeninos y verbos conjugados.
/// Sale del diccionario ortográfico de LibreOffice (RLA-ES, licencia MPL;
/// ver `assets/diccionario/LICENCIA.md`).
///
/// Las palabras se guardan como claves ([LetterWords.key]: minúsculas y
/// sin tildes, con la ñ), ordenadas, en un solo texto: buscar una es una
/// búsqueda binaria, sin armar medio millón de objetos en memoria.
class SpanishDictionary {
  SpanishDictionary._(this._text, this._starts);

  static const asset = 'assets/diccionario/es.txt.gz';

  /// Las palabras, separadas por saltos de línea.
  final String _text;

  /// Dónde empieza cada palabra en [_text].
  final Int32List _starts;

  int get length => _starts.length;

  /// Lo carga de la app, descomprimiéndolo en otro hilo para no trabar la
  /// pantalla (tarda unos cientos de milisegundos).
  static Future<SpanishDictionary> load([AssetBundle? bundle]) async {
    final data = await (bundle ?? rootBundle).load(asset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final (text, starts) = await Isolate.run(() => _decode(bytes));
    return SpanishDictionary._(text, starts);
  }

  /// Lo arma desde el archivo comprimido (para las pruebas).
  static SpanishDictionary fromGzip(List<int> bytes) {
    final (text, starts) = _decode(bytes);
    return SpanishDictionary._(text, starts);
  }

  /// Lo arma desde una lista de palabras (para las pruebas).
  static SpanishDictionary fromWords(Iterable<String> words) {
    final keys = {for (final w in words) LetterWords.key(w)}.toList()..sort();
    final starts = Int32List(keys.length);
    var at = 0;
    for (var i = 0; i < keys.length; i++) {
      starts[i] = at;
      at += keys[i].length + 1;
    }
    return SpanishDictionary._('${keys.join('\n')}\n', starts);
  }

  /// Cada línea del archivo dice cuántas letras repite de la anterior (de
  /// 0 a 9) y el resto: "0casa", "4s" es "casas".
  static (String, Int32List) _decode(List<int> bytes) {
    final lines = const LineSplitter().convert(utf8.decode(gzip.decode(bytes)));
    final out = StringBuffer();
    final starts = Int32List(lines.length);
    var count = 0;
    var at = 0;
    var previous = '';
    for (final line in lines) {
      if (line.isEmpty) continue;
      final shared = line.codeUnitAt(0) - 0x30;
      final word = previous.substring(0, shared) + line.substring(1);
      starts[count++] = at;
      out
        ..write(word)
        ..write('\n');
      at += word.length + 1;
      previous = word;
    }
    return (out.toString(), Int32List.sublistView(starts, 0, count));
  }

  String _wordAt(int i) {
    final start = _starts[i];
    return _text.substring(start, _text.indexOf('\n', start));
  }

  /// Si [word] es una palabra del español ("Árboles", "pingüino" y
  /// "corrimos" sí; "pirulín" o "asdf", no).
  bool contains(String word) {
    final key = LetterWords.key(word);
    if (key.isEmpty) return false;
    var low = 0;
    var high = _starts.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final cmp = _wordAt(mid).compareTo(key);
      if (cmp == 0) return true;
      if (cmp < 0) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return false;
  }
}
