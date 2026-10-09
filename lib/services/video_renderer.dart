import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';

/// Arma el video final de un turno: une las partes grabadas y escribe encima
/// las palabras, los aciertos y los pases, con la fuente del juego.
class VideoRenderer {
  static const _fontAsset = 'assets/fonts/Fredoka_700Bold.ttf';

  int? _sessionId;

  /// Genera el video en [outputPath] y lo devuelve. Prueba primero el
  /// codificador por hardware del celular y, si falla, uno por software.
  /// Lanza una [VideoRenderException] si no se pudo.
  Future<String> render(
    TurnRecording recording, {
    required Directory workDir,
    required String outputPath,
    required int bitrateMbps,
    void Function(double progress)? onProgress,
  }) async {
    final fontsDir = await _prepareFonts(workDir);
    final subtitles = File('${workDir.path}/turno.ass');
    await subtitles.writeAsString(buildSubtitles(recording.captions));

    final encoders = [
      if (Platform.isAndroid) hardwareEncoder('h264_mediacodec', bitrateMbps),
      if (Platform.isIOS) hardwareEncoder('h264_videotoolbox', bitrateMbps),
      softwareEncoder,
    ];
    for (final encoder in encoders) {
      final ok = await _run(
        buildArguments(
          segments: recording.segments,
          subtitlesPath: subtitles.path,
          fontsDir: fontsDir,
          encoder: encoder,
          outputPath: outputPath,
        ),
        recording.duration,
        onProgress,
      );
      if (ok) return outputPath;
    }
    throw const VideoRenderException();
  }

  /// Detiene el proceso en curso, si lo hay.
  Future<void> cancel() async {
    final id = _sessionId;
    if (id != null) await FFmpegKit.cancel(id);
  }

  Future<bool> _run(
    List<String> arguments,
    Duration total,
    void Function(double progress)? onProgress,
  ) async {
    final done = Completer<bool>();
    final session = await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (session) async {
        final code = await session.getReturnCode();
        done.complete(ReturnCode.isSuccess(code));
      },
      null,
      (statistics) {
        if (onProgress == null || total == Duration.zero) return;
        final progress = statistics.getTime() / total.inMilliseconds;
        onProgress(progress.clamp(0.0, 1.0).toDouble());
      },
    );
    _sessionId = session.getSessionId();
    final ok = await done.future;
    _sessionId = null;
    return ok;
  }

  /// Copia la fuente del juego a una carpeta que FFmpeg pueda leer.
  Future<String> _prepareFonts(Directory workDir) async {
    final dir = Directory('${workDir.path}/fonts');
    final font = File('${dir.path}/Fredoka-Bold.ttf');
    if (!await font.exists()) {
      await dir.create(recursive: true);
      final data = await rootBundle.load(_fontAsset);
      await font.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    await FFmpegKitConfig.setFontDirectoryList([dir.path]);
    return dir.path;
  }

  static List<String> hardwareEncoder(String codec, int bitrateMbps) => [
    '-c:v',
    codec,
    '-b:v',
    '${bitrateMbps}M',
  ];

  static const softwareEncoder = ['-c:v', 'mpeg4', '-q:v', '3'];

  /// Argumentos de FFmpeg: une las partes (video y audio) y escribe los
  /// subtítulos encima.
  static List<String> buildArguments({
    required List<String> segments,
    required String subtitlesPath,
    required String fontsDir,
    required List<String> encoder,
    required String outputPath,
  }) {
    final inputs = [
      for (final s in segments) ...['-i', s],
    ];
    final streams = [for (var i = 0; i < segments.length; i++) '[$i:v][$i:a]']
        .join();
    final filter =
        '${streams}concat=n=${segments.length}:v=1:a=1[cv][a];'
        "[cv]ass=filename=${_quote(subtitlesPath)}:fontsdir=${_quote(fontsDir)}[v]";
    return [
      '-y',
      ...inputs,
      '-filter_complex',
      filter,
      '-map',
      '[v]',
      '-map',
      '[a]',
      ...encoder,
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      '-movflags',
      '+faststart',
      outputPath,
    ];
  }

  /// Subtítulos en formato ASS. Las medidas son para un video de 1280x720 y
  /// se ajustan solas al tamaño real del video.
  static String buildSubtitles(List<Caption> captions) {
    final buffer = StringBuffer()
      ..writeln('[Script Info]')
      ..writeln('ScriptType: v4.00+')
      ..writeln('PlayResX: 1280')
      ..writeln('PlayResY: 720')
      ..writeln('WrapStyle: 0')
      ..writeln('ScaledBorderAndShadow: yes')
      ..writeln()
      ..writeln('[V4+ Styles]')
      ..writeln(
        'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, '
        'OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, '
        'ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, '
        'Alignment, MarginL, MarginR, MarginV, Encoding',
      );
    // Texto blanco sobre una caja de color: morado para la palabra, verde
    // para el acierto y naranja para el pase. Los colores van en &HAABBGGRR.
    for (final (name, size, box, align) in [
      ('Title', 80, '&H20E01B6A', 5),
      ('Word', 92, '&H20E01B6A', 8),
      ('Hit', 80, '&H206BC218', 2),
      ('Pass', 80, '&H20008AFF', 2),
    ]) {
      buffer.writeln(
        'Style: $name,Fredoka,$size,&H00FFFFFF,&H00FFFFFF,$box,&H00000000,'
        '-1,0,0,0,100,100,0,0,3,18,0,$align,60,60,48,1',
      );
    }
    buffer
      ..writeln()
      ..writeln('[Events]')
      ..writeln(
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, '
        'Effect, Text',
      );
    for (final caption in captions) {
      if (caption.end <= caption.start) continue;
      final style = switch (caption.style) {
        CaptionStyle.title => 'Title',
        CaptionStyle.word => 'Word',
        CaptionStyle.hit => 'Hit',
        CaptionStyle.pass => 'Pass',
      };
      buffer.writeln(
        'Dialogue: 0,${_time(caption.start)},${_time(caption.end)},$style,,'
        '0,0,0,,${_escape(caption.text)}',
      );
    }
    return buffer.toString();
  }

  /// Tiempo en formato ASS: H:MM:SS.cc
  static String _time(Duration d) {
    final cs = d.inMilliseconds ~/ 10;
    final h = cs ~/ 360000;
    final m = (cs ~/ 6000) % 60;
    final s = (cs ~/ 100) % 60;
    final c = cs % 100;
    String two(int n) => n.toString().padLeft(2, '0');
    return '$h:${two(m)}:${two(s)}.${two(c)}';
  }

  /// Quita los caracteres que ASS interpreta como comandos.
  static String _escape(String text) => text
      .replaceAll('\\', '/')
      .replaceAll('{', '(')
      .replaceAll('}', ')')
      .replaceAll('\n', ' ');

  /// Rutas entre comillas para el filtro de FFmpeg.
  static String _quote(String path) => "'${path.replaceAll("'", r"'\''")}'";
}

class VideoRenderException implements Exception {
  const VideoRenderException();

  @override
  String toString() => 'No se pudo armar el video del turno.';
}
