import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:path_provider/path_provider.dart';

/// Cuándo pedir la reseña de Play Store al terminar una partida: desde la
/// 3.ª partida terminada, si hubo ganador (no empate), si no hubo errores
/// y si no se pidió en los últimos 30 días.
abstract final class ReviewPolicy {
  static const minFinishedGames = 3;
  static const cooldown = Duration(days: 30);

  /// [finishedGames] cuenta la que acaba de terminar.
  static bool shouldAsk({
    required int finishedGames,
    required bool hasWinner,
    required bool hadErrors,
    required DateTime? lastAsked,
    required DateTime now,
  }) {
    if (finishedGames < minFinishedGames) return false;
    if (!hasWinner || hadErrors) return false;
    return lastAsked == null || now.difference(lastAsked) >= cooldown;
  }
}

/// Partidas terminadas y la última vez que se pidió la reseña, guardadas en
/// el celular.
class ReviewRecord {
  const ReviewRecord({this.finishedGames = 0, this.lastAsked});

  factory ReviewRecord.fromJson(Map<String, dynamic> json) => ReviewRecord(
    finishedGames: (json['partidasTerminadas'] as num?)?.toInt() ?? 0,
    lastAsked: DateTime.tryParse('${json['ultimaVez'] ?? ''}'),
  );

  final int finishedGames;
  final DateTime? lastAsked;

  Map<String, dynamic> toJson() => {
    'partidasTerminadas': finishedGames,
    if (lastAsked != null) 'ultimaVez': lastAsked!.toIso8601String(),
  };
}

class ReviewStore {
  ReviewStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const _fileName = 'resena.json';

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  Future<ReviewRecord> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const ReviewRecord();
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, dynamic>
          ? ReviewRecord.fromJson(json)
          : const ReviewRecord();
    } on Object catch (e) {
      debugPrint('[Reseña] No se pudo leer: $e');
      return const ReviewRecord();
    }
  }

  Future<void> save(ReviewRecord record) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(record.toJson()));
    } on Object catch (e) {
      debugPrint('[Reseña] No se pudo guardar: $e');
    }
  }
}

/// La ventana de reseña de Google Play y la ficha de la tienda.
abstract interface class ReviewPrompt {
  Future<bool> isAvailable();
  Future<void> request();
  Future<void> openStore();
}

class PlayReviewPrompt implements ReviewPrompt {
  final _review = InAppReview.instance;

  @override
  Future<bool> isAvailable() => _review.isAvailable();

  @override
  Future<void> request() => _review.requestReview();

  @override
  Future<void> openStore() => _review.openStoreListing();
}

/// Sin tienda: en las pruebas.
class NoReviewPrompt implements ReviewPrompt {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> request() async {}

  @override
  Future<void> openStore() async {}
}

/// Cuenta las partidas terminadas y decide si pedir la reseña.
class ReviewService {
  ReviewService({
    required this.store,
    required this.prompt,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ReviewStore store;
  final ReviewPrompt prompt;
  final DateTime Function() _clock;

  /// Suma una partida terminada y dice si hay que pedir la reseña (sin
  /// pedirla todavía: la pantalla espera un momento).
  Future<bool> gameFinished({
    required bool hasWinner,
    required bool hadErrors,
  }) async {
    final saved = await store.load();
    final record = ReviewRecord(
      finishedGames: saved.finishedGames + 1,
      lastAsked: saved.lastAsked,
    );
    await store.save(record);
    return ReviewPolicy.shouldAsk(
      finishedGames: record.finishedGames,
      hasWinner: hasWinner,
      hadErrors: hadErrors,
      lastAsked: record.lastAsked,
      now: _clock(),
    );
  }

  /// Muestra la ventana de Google Play y guarda la fecha. Google decide si
  /// de verdad aparece (tiene su propio límite).
  Future<void> ask() async {
    try {
      if (!await prompt.isAvailable()) return;
      await prompt.request();
      final saved = await store.load();
      await store.save(
        ReviewRecord(finishedGames: saved.finishedGames, lastAsked: _clock()),
      );
    } on Object catch (e) {
      debugPrint('[Reseña] No se pudo pedir: $e');
    }
  }

  /// "Califica Charadeando": la ficha de Play Store.
  Future<void> openStore() async {
    try {
      await prompt.openStore();
    } on Object catch (e) {
      debugPrint('[Reseña] No se pudo abrir la tienda: $e');
    }
  }
}
