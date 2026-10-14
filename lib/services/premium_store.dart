import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Guarda en el celular lo desbloqueado (Premium y códigos). Se pierde si
/// se desinstala la app: la compra vuelve con "Restaurar compras" y los
/// códigos, con `/juego/mis-codigos`, gracias a [deviceId].
class PremiumStore {
  PremiumStore({
    Future<Directory> Function()? directory,
    Random? random,
    Future<String?> Function()? androidId,
  }) : _directory = directory ?? getApplicationSupportDirectory,
       _random = random ?? Random.secure(),
       _androidId = androidId ?? readAndroidId;

  static const _fileName = 'premium.json';

  final Future<Directory> Function() _directory;
  final Random _random;
  final Future<String?> Function() _androidId;

  static const _channel = MethodChannel('charadeando/dispositivo');

  /// `Settings.Secure.ANDROID_ID`, o null fuera de Android o si no se puede
  /// leer.
  static Future<String?> readAndroidId() async {
    if (!Platform.isAndroid) return null;
    return _channel.invokeMethod<String>('androidId');
  }

  /// Lo que se manda al servidor en vez del ANDROID_ID tal cual.
  static String hashAndroidId(String androidId) =>
      sha256.convert(utf8.encode('charadeando:$androidId')).toString();

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

  /// Identificador de este celular para los códigos: el SHA-256 de su
  /// ANDROID_ID, que no cambia al reinstalar la app. Si no se puede leer,
  /// uno al azar guardado en el celular (se pierde al desinstalar).
  Future<String> deviceId() async {
    try {
      final androidId = (await _androidId())?.trim();
      if (androidId != null && androidId.isNotEmpty) {
        return hashAndroidId(androidId);
      }
    } on Object catch (e) {
      debugPrint('[Premium] No se pudo leer el ANDROID_ID: $e');
    }
    return _randomId();
  }

  /// El identificador al azar de respaldo; se crea la primera vez.
  Future<String> _randomId() async {
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
