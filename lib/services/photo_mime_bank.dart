import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'directus_service.dart';

/// No se pudo preparar Fotomímica. [offline] si fue por falta de internet.
class PhotoMimeException implements Exception {
  const PhotoMimeException(this.message, {this.offline = false});

  final String message;
  final bool offline;

  static const noConnection = PhotoMimeException(
    'Fotomímica necesita internet para descargar las fotos. Revisa tu '
    'conexión e inténtalo otra vez.',
    offline: true,
  );

  @override
  String toString() => 'PhotoMimeException($message)';
}

/// Prepara las fotos de una partida de Fotomímica: pide los objetos a
/// Directus (`/juego/fotomimica`) y descarga TODAS sus fotos al celular
/// antes de empezar, para que en el turno nunca se quede cargando una. Si
/// una foto falla, se usa otro objeto. Sin internet no se puede jugar.
///
/// Recuerda en el celular los ids de los objetos ya jugados, para no
/// repetirlos en las partidas siguientes (como las palabras automáticas).
class PhotoMimeBank {
  PhotoMimeBank(
    this._directus, {
    http.Client? client,
    Future<Directory> Function()? historyDirectory,
    Future<Directory> Function()? cacheDirectory,
    Future<bool> Function(Uint8List bytes)? validate,
  }) : _client = client ?? http.Client(),
       _historyDirectory = historyDirectory ?? getApplicationSupportDirectory,
       _cacheDirectory = cacheDirectory ?? getApplicationCacheDirectory,
       _validate = validate ?? _decodes;

  static const _historyFile = 'fotomimica_vistas.json';
  static const _cacheFolder = 'fotomimica';

  /// Cuántos ids de objetos jugados se recuerdan.
  static const historySize = DirectusService.maxExclude;

  /// Objetos que se preparan como mucho por partida. Si se acaban durante
  /// el juego, vuelven los ya jugados (como con las palabras).
  static const maxPerGame = 90;

  /// Objetos de más que se piden, por si alguna foto falla.
  static const spare = 10;

  /// Fotos que se descargan a la vez.
  static const parallel = 4;

  /// Fotos que se guardan en el celular entre partidas; las más viejas se
  /// borran.
  static const cacheLimit = 300;

  static const _timeout = Duration(seconds: 20);

  final DirectusService _directus;
  final http.Client _client;
  final Future<Directory> Function() _historyDirectory;
  final Future<Directory> Function() _cacheDirectory;
  final Future<bool> Function(Uint8List bytes) _validate;

  /// Objetos para la partida: hasta [count] (como mucho [maxPerGame]), con
  /// su foto ya en el celular, en orden al azar. Con [includePremium]
  /// también salen los de Premium. [onProgress] recibe cuántas fotos están
  /// listas de cuántas. Lanza [PhotoMimeException] sin internet o si no
  /// quedan al menos [minimum] objetos listos.
  Future<List<Word>> prepare(
    int count, {
    required bool includePremium,
    int minimum = 1,
    void Function(int ready, int total)? onProgress,
  }) async {
    final history = await _readHistory();
    final want = count.clamp(1, maxPerGame);
    final List<PhotoMimeItem> fetched;
    try {
      fetched = await _directus.fetchPhotoMime(
        count: min(want + spare, DirectusService.maxPhotoMime),
        exclude: history,
        includePremium: includePremium,
      );
    } on DirectusException catch (e) {
      if (e.statusCode == null) throw PhotoMimeException.noConnection;
      rethrow;
    }
    final seen = <String>{};
    final items = [
      for (final item in fetched)
        if (seen.add(item.id)) item,
    ];
    if (items.length < minimum) {
      throw const PhotoMimeException(
        'Todavía no hay suficientes objetos para jugar Fotomímica. '
        'Inténtalo más tarde.',
      );
    }

    final total = min(want, items.length);
    final folder = Directory('${(await _cacheDirectory()).path}/$_cacheFolder');
    await folder.create(recursive: true);
    final ready = <Word>[];
    var next = 0;
    var networkFailures = 0;
    onProgress?.call(0, total);

    // Cada trabajador toma el siguiente objeto hasta juntar [total]; si una
    // foto falla, el que sigue la reemplaza.
    Future<void> worker() async {
      while (ready.length < total && next < items.length) {
        final item = items[next++];
        try {
          final path = await _download(item, folder);
          if (path == null || ready.length >= total) continue;
          ready.add(
            Word(
              item.nombre,
              category: GameCategory.photoMime.code,
              id: item.id,
              image: path,
            ),
          );
          onProgress?.call(ready.length, total);
        } on _NetworkFailure {
          networkFailures++;
        }
      }
    }

    await Future.wait([for (var i = 0; i < parallel; i++) worker()]);

    if (ready.length < minimum) {
      if (networkFailures > 0) throw PhotoMimeException.noConnection;
      throw const PhotoMimeException(
        'No se pudieron preparar las fotos. Inténtalo otra vez en un momento.',
      );
    }
    await _writeHistory(_remember(history, [for (final w in ready) w.id!]));
    unawaited(_prune(folder));
    return ready..shuffle();
  }

  /// Descarga la foto de [item] en [folder] y devuelve su ruta, o null si
  /// la foto está dañada o no existe. Si ya estaba descargada, no se vuelve
  /// a bajar. Lanza [_NetworkFailure] si no hubo conexión.
  Future<String?> _download(PhotoMimeItem item, Directory folder) async {
    final safe = item.imageId.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '');
    final file = File('${folder.path}/$safe.webp');
    if (await file.exists() && await file.length() > 0) {
      // Así cuenta como recién usada y no se borra al limpiar.
      await file.setLastModified(DateTime.now()).catchError((_) {});
      return file.path;
    }
    final http.Response response;
    try {
      response = await _client.get(Uri.parse(item.imageUrl)).timeout(_timeout);
    } on Exception catch (e) {
      debugPrint('[Fotomímica] Sin respuesta para ${item.nombre}: $e');
      throw const _NetworkFailure();
    }
    final bytes = response.bodyBytes;
    if (response.statusCode != 200 || bytes.isEmpty) {
      debugPrint(
        '[Fotomímica] La foto de ${item.nombre} respondió '
        '${response.statusCode}.',
      );
      return null;
    }
    if (!await _validate(bytes)) {
      debugPrint('[Fotomímica] La foto de ${item.nombre} está dañada.');
      return null;
    }
    // Primero a un archivo temporal, para no dejar fotos a medias.
    final partial = File('${file.path}.parte');
    await partial.writeAsBytes(bytes, flush: true);
    await partial.rename(file.path);
    return file.path;
  }

  /// Si [bytes] es una imagen que se puede mostrar.
  static Future<bool> _decodes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Borra las fotos más viejas si hay más de [cacheLimit].
  Future<void> _prune(Directory folder) async {
    try {
      final files = [
        for (final f in await folder.list().toList())
          if (f is File) f,
      ];
      if (files.length <= cacheLimit) return;
      final dated = [for (final f in files) (f, await f.lastModified())]
        ..sort((a, b) => a.$2.compareTo(b.$2));
      for (final (file, _) in dated.take(files.length - cacheLimit)) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[Fotomímica] No se pudieron limpiar las fotos viejas: $e');
    }
  }

  List<String> _remember(List<String> history, List<String> added) {
    final unique = <String>[];
    final seen = <String>{};
    for (final id in [...history, ...added].reversed) {
      if (seen.add(id)) unique.add(id);
    }
    return unique.take(historySize).toList().reversed.toList();
  }

  Future<File> _history() async =>
      File('${(await _historyDirectory()).path}/$_historyFile');

  /// Ids de los objetos ya jugados, del más viejo al más reciente.
  Future<List<String>> _readHistory() async {
    try {
      final file = await _history();
      if (!await file.exists()) return const [];
      final json = jsonDecode(await file.readAsString());
      return [for (final id in json['vistas'] as List) '$id'];
    } catch (e) {
      // Un archivo dañado no debe impedir jugar.
      debugPrint('[Fotomímica] No se pudo leer el historial: $e');
      return const [];
    }
  }

  Future<void> _writeHistory(List<String> ids) async {
    try {
      final file = await _history();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({'vistas': ids}));
    } catch (e) {
      debugPrint('[Fotomímica] No se pudo guardar el historial: $e');
    }
  }
}

class _NetworkFailure implements Exception {
  const _NetworkFailure();
}
