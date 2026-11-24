import 'dart:io';

import 'package:charadeando_app/models/letter_words.dart';
import 'package:charadeando_app/services/spanish_dictionary.dart';
import 'package:charadeando_app/services/voice_listener.dart';
import 'package:charadeando_app/services/voice_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('comparar palabras', () {
    test('sin tildes, sin mayúsculas, con la ñ', () {
      expect(LetterWords.key('Árbol'), 'arbol');
      expect(LetterWords.key('CANCIÓN'), 'cancion');
      expect(LetterWords.key('pingüino'), 'pinguino');
      expect(LetterWords.key('Ñandú'), 'ñandu');
      expect(LetterWords.key('año'), isNot(LetterWords.key('ano')));
      expect(LetterWords.key('¡Perro!'), 'perro');
    });

    test('repetidas: sin tildes, sin mayúsculas y sin la s final', () {
      String r(String w) => LetterWords.repeatKey(w);
      expect(r('casa'), r('casas'));
      expect(r('Casa'), r('CASAS'));
      expect(r('canción'), r('cancion'));
      expect(r('Pájaros'), r('pajaro'));
      expect(r('niño'), isNot(r('nino')));
      expect(r('perro'), isNot(r('pera')));
      // Una sola letra no se queda vacía.
      expect(r('s'), 's');
    });

    test('empieza con la letra', () {
      expect(LetterWords.startsWith('Árbol', 'A'), isTrue);
      expect(LetterWords.startsWith('ñandú', 'Ñ'), isTrue);
      expect(LetterWords.startsWith('ñandú', 'N'), isFalse);
      expect(LetterWords.startsWith('nube', 'Ñ'), isFalse);
      expect(LetterWords.startsWith('Úrsula', 'u'), isTrue);
      expect(LetterWords.startsWith('', 'A'), isFalse);
    });

    test('separa lo que entendió en palabras', () {
      expect(LetterWords.split('Perro, gato y pato.'), [
        'Perro',
        'gato',
        'y',
        'pato',
      ]);
      expect(LetterWords.split('abre latas 3 ¡pez!'), ['abre', 'latas', 'pez']);
      expect(LetterWords.split('   '), isEmpty);
    });

    test('letras por dificultad: fácil sin Ñ, Q, W, X, Y, K ni Z', () {
      expect(LetterWords.alphabet, hasLength(27));
      expect(LetterWords.easyLetters, hasLength(20));
      for (final l in ['Ñ', 'Q', 'W', 'X', 'Y', 'K', 'Z']) {
        expect(LetterWords.easyLetters, isNot(contains(l)));
      }
    });
  });

  group('revisar palabras de una ronda', () {
    final dictionary = SpanishDictionary.fromWords([
      'perro',
      'perros',
      'pato',
      'patos',
      'piña',
      'pájaro',
    ]);
    WordChecker checker() =>
        WordChecker('P', inDictionary: dictionary.contains);

    test('válida, otra letra, repetida y fuera del diccionario', () {
      final c = checker();
      expect(c.check('perro'), WordVerdict.valid);
      expect(c.check('Perros'), WordVerdict.repeated);
      expect(c.check('gato'), WordVerdict.wrongLetter);
      expect(c.check('pirulín'), WordVerdict.notInDictionary);
      expect(c.check('PAJARO'), WordVerdict.valid);
      expect(c.check('piña'), WordVerdict.valid);
      expect(c.validCount, 3);
    });

    test('una palabra fuera del diccionario no cuenta como dicha', () {
      final c = checker();
      expect(c.check('pirulín'), WordVerdict.notInDictionary);
      expect(c.check('pirulín'), WordVerdict.notInDictionary);
    });

    test('quitar una palabra mal entendida deja decirla otra vez', () {
      final c = checker();
      expect(c.check('pato'), WordVerdict.valid);
      c.remove('patos');
      expect(c.validCount, 0);
      expect(c.check('pato'), WordVerdict.valid);
    });
  });

  group('diccionario de la app', () {
    late SpanishDictionary dictionary;

    setUpAll(() {
      dictionary = SpanishDictionary.fromGzip(
        File(SpanishDictionary.asset).readAsBytesSync(),
      );
    });

    test('tiene casi medio millón de palabras y pesa poco', () {
      expect(dictionary.length, greaterThan(450000));
      expect(File(SpanishDictionary.asset).lengthSync(), lessThan(400 * 1024));
    });

    test('reconoce palabras comunes, plurales, tildes, ñ y verbos', () {
      for (final w in [
        'perro',
        'perros',
        'Casa',
        'árbol',
        'canción',
        'cancion',
        'ñandú',
        'niño',
        'pingüino',
        'corrimos',
        'sacapuntas',
        'paraguas',
        'cumpleaños',
        'rascacielos',
        'kilo',
        'xilófono',
        'yate',
        'zapato',
        'queso',
        'whisky',
      ]) {
        expect(dictionary.contains(w), isTrue, reason: w);
      }
    });

    test('no acepta palabras inventadas ni vacías', () {
      for (final w in ['pirulín', 'asdf', 'perrrro', 'xyz', '', '¡!']) {
        expect(dictionary.contains(w), isFalse, reason: w);
      }
    });
  });

  test('el idioma va con guion para Android (es_US → es-US)', () {
    expect(VoiceTools.tag('es_US'), 'es-US');
    expect(VoiceTools.tag('es-CO'), 'es-CO');
  });

  group('palabras que llegan del reconocimiento de voz', () {
    test('la última de un parcial espera; el final entrega todas', () {
      final s = WordStream();
      expect(s.feed('pe', isFinal: false), isEmpty);
      expect(s.feed('perro', isFinal: false), isEmpty);
      expect(s.feed('perro pato', isFinal: false), ['perro']);
      expect(s.feed('perro pato pez', isFinal: false), ['pato']);
      expect(s.feed('perro pato pez', isFinal: true), ['pez']);
      // Otra frase empieza de cero.
      expect(s.feed('piña', isFinal: true), ['piña']);
    });

    test('no repite palabras si el parcial se corrige', () {
      final s = WordStream();
      expect(s.feed('casa grande', isFinal: false), ['casa']);
      expect(s.feed('casa grande', isFinal: false), isEmpty);
      expect(s.feed('casas grande', isFinal: true), ['grande']);
    });
  });
}
