import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lo que dice Android del reconocimiento de voz en este celular.
class VoiceDiagnosis {
  const VoiceDiagnosis(this.data);

  final Map<String, Object?> data;

  int? get sdk => data['sdk'] as int?;

  /// Hay reconocimiento de voz (normalmente el de Google).
  bool get available => data['reconocimiento'] == true;

  /// El celular puede reconocer sin internet (Android 12 o más nuevo).
  bool get onDevice => data['enCelular'] == true;

  /// Idiomas descargados para reconocer sin internet (Android 13 o más
  /// nuevo; null si el celular no lo dice).
  List<String>? get installed => _list('instalados');
  List<String>? get pending => _list('pendientes');

  List<String>? _list(String key) =>
      (data[key] as List?)?.map((e) => '$e').toList();

  /// Si el español ya está descargado: true, false o null si no se sabe.
  bool? get spanishInstalled {
    final list = installed;
    if (list == null) return null;
    return list.any((l) => l.toLowerCase().startsWith('es'));
  }

  @override
  String toString() => '$data';
}

/// Canal "charadeando/voz" (MainActivity.kt y VoiceTools.kt).
class VoiceTools {
  static const _channel = MethodChannel('charadeando/voz');

  /// "es_US" → "es-US": Android solo entiende el idioma con guion. Con
  /// guion bajo toma el idioma del celular (y pedía descargar inglés).
  static String tag(String language) => language.replaceAll('_', '-');

  static Future<VoiceDiagnosis> diagnose(String language) async {
    try {
      final data = await _channel.invokeMapMethod<String, Object?>(
        'diagnostico',
        tag(language),
      );
      return VoiceDiagnosis(data ?? const {});
    } on Exception catch (e) {
      debugPrint('[Voz] Sin diagnóstico: $e');
      return const VoiceDiagnosis({});
    }
  }

  /// Pide al sistema descargar el español para reconocer sin internet.
  static Future<bool> downloadLanguage(String language) async {
    try {
      return await _channel.invokeMethod<bool>(
            'descargarIdioma',
            tag(language),
          ) ??
          false;
    } on Exception {
      return false;
    }
  }

  /// Silencia los sonidos del sistema y de notificaciones (el "bip" de
  /// cada vez que empieza a escuchar) o los deja como estaban.
  static Future<bool> muteBeep(bool on) async {
    try {
      return await _channel.invokeMethod<bool>('silenciarBip', on) ?? false;
    } on Exception {
      return false;
    }
  }
}
