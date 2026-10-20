import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/services/video_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

Duration ms(int value) => Duration(milliseconds: value);

void main() {
  group('buildSubtitles', () {
    test('escribe cada texto con su estilo y sus tiempos', () {
      final ass = VideoRenderer.buildSubtitles([
        Caption('¡Turno de Los Tigres!', CaptionStyle.title, ms(0), ms(3000)),
        Caption('El Rey León', CaptionStyle.word, ms(3000), ms(64250)),
        Caption('¡Correcto!', CaptionStyle.hit, ms(64250), ms(64950)),
        Caption('Paso', CaptionStyle.pass, ms(3723450), ms(3724000)),
      ]);
      expect(
        ass,
        contains(
          'Dialogue: 0,0:00:00.00,0:00:03.00,Title,,0,0,0,,¡Turno de Los Tigres!',
        ),
      );
      expect(ass, contains('0:00:03.00,0:01:04.25,Word,,0,0,0,,El Rey León'));
      expect(ass, contains('0:01:04.25,0:01:04.95,Hit,'));
      expect(ass, contains('1:02:03.45,1:02:04.00,Pass,'));
      expect(ass, contains('Style: Word,Fredoka,'));
    });

    test('en una mezcla, la categoría va arriba de la palabra', () {
      final ass = VideoRenderer.buildSubtitles([
        Caption(
          'El Rey León',
          CaptionStyle.word,
          ms(0),
          ms(1000),
          label: 'Película',
        ),
      ]);
      expect(ass, contains(r',,{\fs44}Película\N{\r}El Rey León'));
    });

    test('ignora textos sin duración y quita los comandos de ASS', () {
      final ass = VideoRenderer.buildSubtitles([
        Caption('Vacío', CaptionStyle.word, ms(500), ms(500)),
        Caption(r'{\b1}Hola\N', CaptionStyle.word, ms(0), ms(1000)),
      ]);
      expect(ass, isNot(contains('Vacío')));
      expect(ass, contains(',,(/b1)Hola/N'));
    });
  });

  test('buildArguments une todas las partes y escribe los subtítulos', () {
    final args = VideoRenderer.buildArguments(
      segments: ['/v/a.mp4', '/v/b.mp4'],
      subtitlesPath: '/v/turno.ass',
      fontsDir: '/v/fonts',
      encoder: VideoRenderer.softwareEncoder,
      outputPath: '/v/final.mp4',
    );
    expect(args.where((a) => a == '-i'), hasLength(2));
    final filter = args[args.indexOf('-filter_complex') + 1];
    expect(
      filter,
      "[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1[cv][a];"
      "[cv]ass=filename='/v/turno.ass':fontsdir='/v/fonts'[v]",
    );
    expect(args.last, '/v/final.mp4');
  });

  test('buildArguments con marca de agua pone el logo abajo a la derecha', () {
    final args = VideoRenderer.buildArguments(
      segments: ['/v/a.mp4', '/v/b.mp4'],
      subtitlesPath: '/v/turno.ass',
      fontsDir: '/v/fonts',
      encoder: VideoRenderer.softwareEncoder,
      outputPath: '/v/final.mp4',
      watermarkPath: '/v/marca_agua.png',
      watermarkPixels: VideoRenderer.watermarkPixels(1280),
    );
    // El logo es la tercera entrada, después de las partes.
    expect(args.where((a) => a == '-i'), hasLength(3));
    expect(args[args.lastIndexOf('-i') + 1], '/v/marca_agua.png');
    final filter = args[args.indexOf('-filter_complex') + 1];
    expect(
      filter,
      "[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1[cv][a];"
      "[cv]ass=filename='/v/turno.ass':fontsdir='/v/fonts'[sv];"
      '[2:v]scale=256:-1,format=rgba,colorchannelmixer=aa=0.85[wm];'
      '[sv][wm]overlay=x=W-w-W*0.025:y=H-h-H*0.035[v]',
    );
    // El 20 % del ancho del video, siempre par.
    expect(VideoRenderer.watermarkPixels(1920), 384);
    expect(VideoRenderer.watermarkPixels(1000), 200);
    expect(args, containsAllInOrder(['-map', '[v]', '-map', '[a]']));
  });

  test('buildArguments sin audio no pide pistas de audio', () {
    final args = VideoRenderer.buildArguments(
      segments: ['/v/a.mp4', '/v/b.mp4'],
      subtitlesPath: '/v/turno.ass',
      fontsDir: '/v/fonts',
      encoder: VideoRenderer.softwareEncoder,
      outputPath: '/v/final.mp4',
      withAudio: false,
    );
    final filter = args[args.indexOf('-filter_complex') + 1];
    expect(filter, startsWith('[0:v][1:v]concat=n=2:v=1:a=0[cv];'));
    expect(args, contains('-an'));
    expect(args, isNot(contains('[a]')));
  });
}
