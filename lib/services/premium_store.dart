import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Guarda en el celular lo desbloqueado (Premium y códigos) y un
/// identificador al azar del celular, para que el servidor sepa si este
/// celular ya canjeó un código. Se pierde si se desinstala la app: la
/// compra vuelve con "Restaurar compras" y los códigos, canjeándolos otra
/// vez (en el mismo celular no gastan otro uso mientras el identificador
/// sea el mismo).
class PremiumStore {
  PremiumStore({Future<Directory> Function()? directory, Random? random})
    : _directory = directory ?? getApplicationSupportDirectory,
      _random = random ?? Random.secure();

  static const _fileName = 'premium.json';

  final Future<Directory> Function() _directory;
  final Random _random;

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  Future<Map<String, dynamic>> _read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return {};
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, dynamic> ? json : {};
    } on Exception catch (e) {
      debugPrint('[Premium] No se pudo leer: $e');
      return {};
    }
  }

  Future<void> _write(Map<String, dynamic> json) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(json));
    } on Exception catch (e) {
      debugPrint('[Premium] No se pudo guardar: $e');
    }
  }

  Future<PremiumAccess> load() async => PremiumAccess.fromJson(await _read());

  Future<void> save(PremiumAccess access) async =>
      _write({...await _read(), ...access.toJson()});

  /// Identificador de este celular; se crea la primera vez.
  Future<String> deviceId() async {
    final json = await _read();
    final saved = json['dispositivo'];
    if (saved is String && saved.length >= 8) return saved;
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final id = String.fromCharCodes([
      for (var i = 0; i < 24; i++)
        chars.codeUnitAt(_random.nextInt(chars.length)),
    ]);
    await _write({...json, 'dispositivo': id});
    return id;
  }
}
