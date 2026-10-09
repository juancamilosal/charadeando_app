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
}
