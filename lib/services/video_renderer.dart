import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';

/// Arma el video final de un turno: une las partes grabadas y escribe encima
/// las palabras, los aciertos y los pases, con la fuente del juego. Sin
/// Premium lleva el logo de Charadeando como marca de agua.
class VideoRenderer {
  static const _fontAsset = 'assets/fonts/Fredoka_700Bold.ttf';
  static const _watermarkAsset = 'assets/img/marca/marca_agua.png';

  /// Ancho de la marca de agua, como parte del ancho del video.
  static const watermarkWidth = 0.2;

  int? _sessionId;

  /// Genera el video en [outputPath] y lo devuelve. Prueba primero el
  /// codificador por hardware del celular y, si falla, uno por software.
  /// Con [watermark] pone el logo en la esquina; si así no se puede armar,
  /// lo arma sin él antes de rendirse. Lanza una [VideoRenderException] si
  /// no se pudo.
  Future<String> render(
    TurnRecording recording, {
    required Directory workDir,
    required String outputPath,
    required int bitrateMbps,
    bool watermark = false,
    String? subtitles,
    void Function(double progress)? onProgress,
  }) async {
    final fontsDir = await _prepareFonts(workDir);
    final logo = watermark ? await _prepareWatermark(workDir) : null;
    final logoWidth = logo == null
        ? 0
        : watermarkPixels(await _videoWidth(recording.segments.first));
    // [subtitles] trae los textos ya armados (Letras, en vertical); si no,
    // se arman con los del turno.
    final customSubtitles = subtitles;
    final subtitlesFile = File('${workDir.path}/turno.ass');
    await subtitlesFile.writeAsString(
      customSubtitles ?? buildSubtitles(recording.captions),
    );

    final encoders = [
      if (Platform.isAndroid) hardwareEncoder('h264_mediacodec', bitrateMbps),
      if (Platform.isIOS) hardwareEncoder('h264_videotoolbox', bitrateMbps),
      softwareEncoder,
    ];
    // Algunas grabaciones no traen audio (por ejemplo, en el emulador o si
    // se negó el micrófono). Si falta en alguna parte, se arma sin audio; y
    // si con audio falla, se intenta una última vez sin él.
    final hasAudio = await _allHaveAudio(recording.segments);
    String? lastLogs;
    for (final watermarkPath in [logo, if (logo != null) null]) {
      for (final withAudio in [hasAudio, if (hasAudio) false]) {
        for (final encoder in encoders) {
          final failure = await _run(
            buildArguments(
              segments: recording.segments,
              subtitlesPath: subtitlesFile.path,
              fontsDir: fontsDir,
              encoder: encoder,
              outputPath: outputPath,
              withAudio: withAudio,
              watermarkPath: watermarkPath,
              watermarkPixels: logoWidth,
            ),
            recording.duration,
            onProgress,
          );
          if (failure == null) return outputPath;
          lastLogs = failure;
        }
      }
    }
    debugPrint('[Charadeando] No se pudo armar el video del turno:\n$lastLogs');
    throw VideoRenderException(lastLogs);
  }

  Future<bool> _allHaveAudio(List<String> segments) async {
    for (final segment in segments) {
      try {
        final session = await FFprobeKit.getMediaInformation(segment);
        final streams = session.getMediaInformation()?.getStreams();
        if (streams == null) continue;
        if (!streams.any((s) => s.getType() == 'audio')) return false;
      } on Exception {
        // Si no se puede revisar, se intenta con audio.
      }
    }
    return true;
  }

  /// Detiene el proceso en curso, si lo hay.
  Future<void> cancel() async {
    final id = _sessionId;
    if (id != null) await FFmpegKit.cancel(id);
  }

  /// Ejecuta FFmpeg. Devuelve null si salió bien, o los últimos mensajes
  /// de FFmpeg si falló.
  Future<String?> _run(
    List<String> arguments,
    Duration total,
    void Function(double progress)? onProgress,
  ) async {
    final done = Completer<String?>();
    final session = await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (session) async {
        final code = await session.getReturnCode();
        if (ReturnCode.isSuccess(code)) {
          done.complete(null);
          return;
        }
        final logs = (await session.getAllLogsAsString() ?? '').trim();
        final lines = logs.split('\n');
        final tail = lines.skip(lines.length > 25 ? lines.length - 25 : 0);
        done.complete('Código ${code?.getValue()}:\n${tail.join('\n')}');
      },
      null,
      (statistics) {
        if (onProgress == null || total == Duration.zero) return;
        final progress = statistics.getTime() / total.inMilliseconds;
        onProgress(progress.clamp(0.0, 1.0).toDouble());
      },
    );
    _sessionId = session.getSessionId();
    final result = await done.future;
    _sessionId = null;
    return result;
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

  /// Ancho del video grabado, para el tamaño de la marca de agua. Si no se
  /// puede saber, el de un video HD.
  Future<int> _videoWidth(String segment) async {
    try {
      final session = await FFprobeKit.getMediaInformation(segment);
      for (final s in session.getMediaInformation()?.getStreams() ?? []) {
        final width = s.getWidth();
        if (s.getType() == 'video' && width != null && width > 0) {
          // El turno se graba en horizontal: el ancho es el lado largo
          // (la cámara a veces guarda la rotación aparte).
          final height = s.getHeight() ?? width;
          return width > height ? width : height;
        }
      }
    } on Exception {
      // Se usa el de HD.
    }
    return 1280;
  }

  /// Ancho del logo en píxeles para un video de [videoWidth] (par, como
  /// le gusta a los codificadores).
  static int watermarkPixels(int videoWidth) =>
      (videoWidth * watermarkWidth / 2).round() * 2;

  /// Copia el logo de la marca de agua a una carpeta que FFmpeg pueda leer.
  /// Si no se puede, el video sale sin él.
  Future<String?> _prepareWatermark(Directory workDir) async {
    try {
      final file = File('${workDir.path}/marca_agua.png');
      if (!await file.exists()) {
        final data = await rootBundle.load(_watermarkAsset);
        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
      return file.path;
    } on Exception catch (e) {
      debugPrint('[Charadeando] Sin marca de agua: $e');
      return null;
    }
  }

  static List<String> hardwareEncoder(String codec, int bitrateMbps) => [
    '-c:v',
    codec,
    '-b:v',
    '${bitrateMbps}M',
  ];

  static const softwareEncoder = ['-c:v', 'mpeg4', '-q:v', '3'];

  /// Argumentos de FFmpeg: une las partes (video y audio), escribe los
  /// subtítulos encima y, con [watermarkPath], pone el logo abajo a la
  /// derecha, de [watermarkPixels] de ancho y un poco transparente (abajo al
  /// centro van "¡Correcto!" y "Paso").
  static List<String> buildArguments({
    required List<String> segments,
    required String subtitlesPath,
    required String fontsDir,
    required List<String> encoder,
    required String outputPath,
    bool withAudio = true,
    String? watermarkPath,
    int watermarkPixels = 256,
  }) {
    final inputs = [
      for (final s in segments) ...['-i', s],
      if (watermarkPath != null) ...['-i', watermarkPath],
    ];
    final streams = [
      for (var i = 0; i < segments.length; i++)
        withAudio ? '[$i:v][$i:a]' : '[$i:v]',
    ].join();
    final concat = withAudio
        ? 'concat=n=${segments.length}:v=1:a=1[cv][a]'
        : 'concat=n=${segments.length}:v=1:a=0[cv]';
    final ass =
        "[cv]ass=filename=${_quote(subtitlesPath)}:fontsdir=${_quote(fontsDir)}";
    final logo = segments.length;
    final filter = watermarkPath == null
        ? '$streams$concat;$ass[v]'
        : '$streams$concat;$ass[sv];'
              '[$logo:v]scale=$watermarkPixels:-1,format=rgba,'
              'colorchannelmixer=aa=0.85[wm];'
              '[sv][wm]overlay=x=W-w-W*0.025:y=H-h-H*0.035[v]';
    return [
      '-y',
      ...inputs,
      '-filter_complex',
      filter,
      '-map',
      '[v]',
      if (withAudio) ...['-map', '[a]'],
      ...encoder,
      '-pix_fmt',
      'yuv420p',
      if (withAudio) ...['-c:a', 'aac', '-b:a', '128k'] else '-an',
      '-movflags',
      '+faststart',
      outputPath,
    ];
  }

  /// Subtítulos del video de La Bomba (Letras), vertical (720x1280):
  /// arriba la [topic] hasta el BOOM; debajo, un momento, la letra que
  /// eligió cada quien ([picks]: cuándo y cuál; no en el centro, para no
  /// tapar la cara); los avisos de fin de ronda ([notices]: desde, hasta y
  /// texto), y en [boomAt] la explosión: destello, bola de fuego, chispas,
  /// humo, las [letters] de la rueda que salen volando y "¡BOOM!", hasta
  /// [end].
  static String lettersSubtitles({
    required String topic,
    required List<(Duration, String)> picks,
    List<(Duration, Duration, String)> notices = const [],
    required Duration boomAt,
    required Duration end,
    List<String> letters = const [],
  }) {
    final buffer = StringBuffer()
      ..writeln('[Script Info]')
      ..writeln('ScriptType: v4.00+')
      ..writeln('PlayResX: 720')
      ..writeln('PlayResY: 1280')
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
    // Temática arriba en una caja morada; la letra elegida, blanca con
    // borde morado, debajo; el aviso de ronda, en una caja verde; el BOOM,
    // amarillo con borde rojo, en el centro. Fx son las figuras de la
    // explosión.
    for (final (name, size, color, box, border, align, marginV) in [
      ('Topic', 56, '&H00FFFFFF', '&H20E01B6A', 3, 8, 70),
      ('Letter', 230, '&H00FFFFFF', '&H00E01B6A', 1, 8, 175),
      ('Notice', 60, '&H00FFFFFF', '&H206BC218', 3, 8, 200),
      ('Boom', 200, '&H003FD2FF', '&H002839D6', 1, 5, 0),
      ('Fx', 20, '&H00FFFFFF', '&H00000000', 1, 5, 0),
      ('Fly', 58, '&H00571A2B', '&H00FFFFFF', 1, 5, 0),
    ]) {
      final outline = name == 'Fx' || name == 'Fly'
          ? 0
          : (border == 3 ? 18 : 14);
      buffer.writeln(
        'Style: $name,Fredoka,$size,$color,$color,$box,&H00000000,'
        '-1,0,0,0,100,100,0,0,$border,$outline,0,$align,50,50,$marginV,1',
      );
    }
    buffer
      ..writeln()
      ..writeln('[Events]')
      ..writeln(
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, '
        'Effect, Text',
      );
    void line(
      int layer,
      Duration from,
      Duration to,
      String style,
      String text,
    ) {
      if (to <= from) return;
      buffer.writeln(
        'Dialogue: $layer,${_time(from)},${_time(to)},$style,,0,0,0,,$text',
      );
    }

    line(0, Duration.zero, boomAt, 'Topic', _escape(topic));
    for (final (at, letter) in picks) {
      final until = at + const Duration(milliseconds: 1200);
      line(
        1,
        at,
        until < boomAt ? until : boomAt,
        'Letter',
        '{\\fad(60,250)}${_escape(letter)}',
      );
    }
    for (final (from, to, text) in notices) {
      line(1, from, to, 'Notice', _escape(text));
    }
    _explosion(line, boomAt, end);
    _flyingLetters(line, letters, boomAt, end);
    line(
      13,
      boomAt,
      end,
      'Boom',
      '{\\frz6\\fscx20\\fscy20\\t(0,350,\\fscx110\\fscy110)'
          '\\t(350,550,\\fscx100\\fscy100)}¡BOOM!',
    );
    return buffer.toString();
  }

  /// Círculo de 200 de diámetro para dibujar en ASS (con \p1).
  static const _circle =
      'm 100 0 b 155 0 200 45 200 100 b 200 155 155 200 100 200 '
      'b 45 200 0 155 0 100 b 0 45 45 0 100 0';
  static const _screen = 'm 0 0 l 720 0 l 720 1280 l 0 1280';

  /// La explosión dibujada en el video: se oscurece, sale humo, una bola
  /// de fuego en capas que crece, chispas que vuelan y un destello blanco.
  static void _explosion(
    void Function(int, Duration, Duration, String, String) line,
    Duration at,
    Duration end,
  ) {
    Duration after(int ms) => at + Duration(milliseconds: ms);
    final random = Random(7);
    line(
      2,
      at,
      end,
      'Fx',
      '{\\an7\\pos(0,0)\\p1\\1c&H0B0B1A&\\1a&H40&\\fad(150,0)}$_screen',
    );
    for (var i = 0; i < 10; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final distance = 120 + random.nextDouble() * 250;
      final x = (360 + cos(angle) * distance).round();
      final y = (640 + sin(angle) * distance).round();
      line(
        3,
        after(300),
        end,
        'Fx',
        '{\\an5\\pos($x,$y)\\p1\\1c&H50505A&\\1a&HFF&\\blur40\\fscx80\\fscy80'
            '\\t(0,1500,\\1a&H90&\\fscx220\\fscy220)}$_circle',
      );
    }
    final layers = [
      ('&H2839D6&', '&H20&', 700, 60),
      ('&H008AFF&', '&H10&', 520, 45),
      ('&H3FD2FF&', '&H00&', 330, 30),
      ('&HFFFFFF&', '&H00&', 160, 25),
    ];
    for (var i = 0; i < layers.length; i++) {
      final (color, alpha, scale, blur) = layers[i];
      line(
        4 + i,
        at,
        after(1800),
        'Fx',
        '{\\an5\\pos(360,640)\\p1\\1c$color\\1a$alpha\\bord0\\shad0'
            '\\blur$blur\\fscx10\\fscy10\\t(0,450,0.6,\\fscx$scale\\fscy$scale)'
            '\\fad(0,1000)}$_circle',
      );
    }
    for (var i = 0; i < 36; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final speed = 250 + random.nextDouble() * 450;
      final x = (360 + cos(angle) * speed).round();
      final y = (640 + sin(angle) * speed + 120).round();
      final size = 6 + random.nextInt(11);
      final color = random.nextBool() ? '&H3FD2FF&' : '&H008AFF&';
      line(
        9,
        at,
        after(1300),
        'Fx',
        '{\\an5\\move(360,640,$x,$y,0,1200)\\p1\\1c$color\\bord0\\shad0'
            '\\fscx$size\\fscy$size\\fad(0,500)}$_circle',
      );
    }
    line(
      10,
      at,
      after(350),
      'Fx',
      '{\\an7\\pos(0,0)\\p1\\1c&HFFFFFF&\\fad(0,330)}$_screen',
    );
  }

  /// Las letras de la rueda salen de un óvalo alrededor del centro hacia
  /// afuera, girando y cayendo, por encima de la bola de fuego.
  static void _flyingLetters(
    void Function(int, Duration, Duration, String, String) line,
    List<String> letters,
    Duration at,
    Duration end,
  ) {
    final random = Random(3);
    final until = at + const Duration(milliseconds: 2600);
    for (var i = 0; i < letters.length; i++) {
      final angle = -pi / 2 + i * 2 * pi / letters.length;
      final push = angle + (random.nextDouble() - 0.5) * 0.6;
      final speed = 250 + random.nextDouble() * 250;
      final spin = ((random.nextDouble() - 0.5) * 720).round();
      final x1 = (360 + cos(angle) * 290).round();
      final y1 = (640 + sin(angle) * 380).round();
      final x2 = (x1 + cos(push) * speed).round();
      final y2 = (y1 + sin(push) * speed + 500).round();
      final move = '\\move($x1,$y1,$x2,$y2,0,2500)';
      final to = until < end ? until : end;
      // El botón blanco con borde morado y, encima, la letra que gira.
      line(
        11,
        at,
        to,
        'Fx',
        '{\\an5$move\\p1\\1c&HFFFFFF&\\3c&H571A2B&\\bord5\\shad0'
            '\\fscx42\\fscy42}$_circle',
      );
      line(
        12,
        at,
        to,
        'Fly',
        '{\\an5$move\\t(0,2500,\\frz$spin)}${_escape(letters[i])}',
      );
    }
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
      // En una mezcla, la categoría va arriba de la palabra, más pequeña.
      final label = caption.label;
      final answer = caption.answer;
      final text = answer != null
          // ¿Más o menos?: el tema y la pregunta más pequeños y la
          // respuesta grande.
          ? [
              if (label != null) '{\\fs40}${_escape(label)}',
              '{\\fs52}${_escape(caption.text)}',
              '{\\r}${_escape(answer)}',
            ].join('\\N')
          : label == null
          ? _escape(caption.text)
          : '{\\fs44}${_escape(label)}\\N{\\r}${_escape(caption.text)}';
      buffer.writeln(
        'Dialogue: 0,${_time(caption.start)},${_time(caption.end)},$style,,'
        '0,0,0,,$text',
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
  const VideoRenderException([this.details]);

  /// Últimos mensajes de FFmpeg, para diagnosticar.
  final String? details;

  @override
  String toString() => 'No se pudo armar el video del turno.\n${details ?? ''}';
}
