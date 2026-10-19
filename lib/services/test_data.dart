import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Datos para probar la app sin tener que configurar ni escribir palabras.
///
/// El botón "Ingresar valores de prueba" solo se muestra en modo debug
/// (`flutter run`); en la versión de lanzamiento no aparece.
abstract final class TestData {
  static const enabled = kDebugMode;

  static const config = GameConfig(
    groups: [Group('Los Tigres'), Group('Las Águilas')],
    rounds: 2,
    turnDuration: Duration(seconds: 60),
    wordsPerGroup: 10,
  );

  static const _words = [
    'Pizza',
    'Elefante',
    'Titanic',
    'Shakira',
    'Bicicleta',
    'Cumpleaños',
    'Harry Potter',
    'Fútbol',
    'Guitarra',
    'Estoy durmiendo',
    'Jirafa',
    'Colombia',
    'El Rey León',
    'Helado',
    'Avión',
    'Bailar salsa',
    'Spider-Man',
    'Café',
    'Playa',
    'Messi',
    'Pingüino',
    'Paraguas',
    'Cepillarse los dientes',
    'Nevera',
    'Mariposa',
  ];

  /// [count] palabras de prueba distintas, elegidas al azar. Si se piden
  /// más de las que hay en la lista, se completan con palabras numeradas.
  static List<Word> sample(int count, {Random? random}) {
    final pool = [..._words]..shuffle(random ?? Random());
    return [
      for (var i = 0; i < count; i++)
        Word(i < pool.length ? pool[i] : 'Palabra de prueba ${i + 1}'),
    ];
  }

  /// Palabras distintas para cada grupo, elegidas al azar.
  static List<List<Word>> words({Random? random}) {
    final pool = [..._words]..shuffle(random ?? Random());
    final perGroup = config.wordsPerGroup;
    return [
      for (var g = 0; g < config.groupCount; g++)
        [for (final w in pool.skip(g * perGroup).take(perGroup)) Word(w)],
    ];
  }
}
