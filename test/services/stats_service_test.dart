import 'dart:convert';
import 'dart:io';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Un turno con [hits] aciertos y [passes] pases.
Turn _turn(int hits, int passes) => Turn(
  round: 1,
  groupIndex: 0,
  entries: [
    for (var i = 0; i < hits; i++) TurnEntry(Word('A$i'), WordOutcome.hit),
    for (var i = 0; i < passes; i++) TurnEntry(Word('P$i'), WordOutcome.pass),
  ],
);

Map<String, Object?> _stats(
  GameConfig config, {
  List<Turn>? turns,
  bool finished = true,
  PlayController controller = PlayController.tilt,
}) => GameStats.build(
  config: config,
  turns: turns ?? [_turn(3, 1)],
  finished: finished,
  controller: controller,
  version: '1.0.0+1',
);

void main() {
  group('lo que se envía de una partida', () {
    test('una categoría del juego', () {
      final s = _stats(
        const GameConfig(
          category: GameCategory.animals,
          groups: [Group('Tigres'), Group('Águilas')],
          rounds: 3,
          turnDuration: Duration(seconds: 60),
          wordSource: WordSource.random,
        ),
        turns: [_turn(5, 2), _turn(4, 0)],
      );
      expect(s['modo'], 'NORMAL');
      expect(s['categorias'], [GameCategory.animals.code]);
      expect(s['dificultad'], 'MEZCLADA');
      expect(s['equipos'], 2);
      expect(s['rondas'], 3);
      expect(s['duracion_turno'], 60);
      expect(s['palabras_jugadas'], 11);
      expect(s['aciertos'], 9);
      expect(s['pases'], 2);
      expect(s['modo_acierto'], 'INCLINACION');
      expect(s['terminada'], isTrue);
      expect(s['video'], isTrue);
      expect(s['version_app'], '1.0.0+1');
    });

    test('nunca lleva nombres de equipos ni nada del celular', () {
      final s = _stats(
        const GameConfig(groups: [Group('Los Primos'), Group('La Oficina')]),
      );
      final text = jsonEncode(s);
      expect(text, isNot(contains('Primos')));
      expect(text, isNot(contains('Oficina')));
      expect(
        s.keys,
        unorderedEquals([
          'modo',
          'categorias',
          'dificultad',
          'equipos',
          'rondas',
          'duracion_turno',
          'palabras_jugadas',
          'aciertos',
          'pases',
          'modo_acierto',
          'terminada',
          'video',
          'version_app',
        ]),
      );
    });

    test('Mis categorías llega solo como MIS_CATEGORIAS, sin nombre ni '
        'palabras', () {
      final mine = CustomCategory(
        id: 'f1',
        name: 'Mi familia',
        words: const ['Tía Rosa', 'Abuelo'],
      );
      final s = _stats(
        GameConfig(customCategory: mine, wordSource: WordSource.random),
      );
      expect(s['modo'], 'MIS_CATEGORIAS');
      expect(s['categorias'], ['MIS_CATEGORIAS']);
      expect(s['dificultad'], isNull);
      final text = jsonEncode(s);
      expect(text, isNot(contains('familia')));
      expect(text, isNot(contains('Rosa')));
    });

    test('Combinar categorías', () {
      final mine = CustomCategory(
        id: 'f1',
        name: 'Mi familia',
        words: const [],
      );
      final s = _stats(
        GameConfig(
          mixCategories: const [GameCategory.animals, GameCategory.movies],
          mixCustom: [mine],
          wordSource: WordSource.random,
          difficulty: Difficulty.easy,
        ),
      );
      expect(s['modo'], 'COMBINADA');
      expect(s['categorias'], [
        GameCategory.animals.code,
        GameCategory.movies.code,
        'MIS_CATEGORIAS',
      ]);
      expect(s['dificultad'], 'FACIL');
    });

    test('Libre y Fotomímica', () {
      final free = _stats(const GameConfig(category: GameCategory.free));
      expect(free['modo'], 'LIBRE');
      expect(free['categorias'], [GameCategory.free.code]);
      final photos = _stats(
        const GameConfig(
          category: GameCategory.photoMime,
          wordSource: WordSource.random,
        ),
      );
      expect(photos['modo'], 'FOTOMIMICA');
      expect(photos['categorias'], ['FOTOMIMICA']);
      expect(photos['dificultad'], isNull);
    });

    test('cómo se marcaron los aciertos y si hubo video', () {
      expect(
        _stats(
          const GameConfig(),
          controller: PlayController.touch,
        )['modo_acierto'],
        'TOQUE',
      );
      final judge = _stats(const GameConfig(judgePhone: true));
      expect(judge['modo_acierto'], 'JUEZ');
      final tv = _stats(const GameConfig(hitMode: HitMode.tv));
      expect(tv['modo_acierto'], 'TV');
      expect(tv['video'], isFalse);
      expect(
        _stats(const GameConfig(resolution: VideoResolution.off))['video'],
        isFalse,
      );
    });

    test('sin equipos son 0 equipos; abandonada, no terminada', () {
      final s = _stats(
        const GameConfig(inGroups: false, groups: [Group('')]),
        finished: false,
      );
      expect(s['equipos'], 0);
      expect(s['terminada'], isFalse);
    });
  });

  group('la cola en el celular', () {
    late Directory dir;
    late List<Map<String, dynamic>> received;
    late int status;
    late bool offline;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('estadisticas');
      received = [];
      status = 201;
      offline = false;
    });
    tearDown(() => dir.delete(recursive: true));

    StatsService service() => StatsService(
      baseUrl: 'https://servidor',
      directory: () async => dir,
      version: () async => '1.0.0+1',
      client: MockClient((request) async {
        if (offline) throw const SocketException('Sin internet');
        expect(request.url.toString(), 'https://servidor/juego/partida');
        received.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('{}', status);
      }),
    );

    Future<void> record(StatsService s) => s.record(
      config: const GameConfig(),
      turns: [_turn(2, 1)],
      finished: true,
      controller: PlayController.tilt,
    );

    Future<int> pending() async {
      final file = File('${dir.path}/estadisticas_pendientes.json');
      if (!await file.exists()) return 0;
      return (jsonDecode(await file.readAsString()) as List).length;
    }

    test('con internet se envía y no queda nada pendiente', () async {
      await record(service());
      expect(received, hasLength(1));
      expect(received.single['aciertos'], 2);
      expect(await pending(), 0);
    });

    test('sin internet se guarda y se envía después', () async {
      offline = true;
      final s = service();
      await record(s);
      await record(s);
      expect(await pending(), 2);
      expect(received, isEmpty);

      offline = false;
      await s.flush();
      expect(received, hasLength(2));
      expect(await pending(), 0);
    });

    test('guarda como mucho 50: se descartan las más viejas', () async {
      offline = true;
      final s = service();
      for (var i = 0; i < StatsService.maxQueue + 5; i++) {
        await record(s);
      }
      expect(await pending(), StatsService.maxQueue);
    });

    test(
      'si el servidor falla se reintenta; si la rechaza, se descarta',
      () async {
        status = 500;
        final s = service();
        await record(s);
        expect(await pending(), 1);

        status = 400;
        await s.flush();
        expect(await pending(), 0);
      },
    );

    test('con el ajuste apagado no se envía ni se guarda nada', () async {
      final s = service()..enabled = false;
      await record(s);
      await s.flush();
      expect(received, isEmpty);
      expect(await pending(), 0);
    });

    test('al apagar el ajuste se borra lo pendiente', () async {
      offline = true;
      final s = service();
      await record(s);
      await s.clear();
      expect(await pending(), 0);
    });

    test('nunca lanza errores, aunque no se pueda escribir', () async {
      final s = StatsService(
        directory: () async => throw const FileSystemException('Sin disco'),
        version: () async => '1.0.0',
        client: MockClient((_) async => http.Response('{}', 201)),
      );
      await record(s);
      await s.flush();
    });
  });
}
