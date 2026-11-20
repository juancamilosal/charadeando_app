import 'dart:convert';
import 'dart:io';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:charadeando_app/widgets/fact_view.dart';
import 'package:charadeando_app/widgets/number_stepper.dart';
import 'package:charadeando_app/widgets/config_section.dart';
import 'package:charadeando_app/widgets/result_parts.dart';
import 'package:charadeando_app/widgets/word_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'config_screen_test.dart'
    show MemoryConfigStore, pumpConfig, tapContinue;

/// Un dato de prueba.
Word fact(int id, {String? note, String difficulty = 'FACIL'}) =>
    FactsBank.wordOf(
      FactItem(
        id: '$id',
        question: '¿Cuántas cosas tiene el dato número $id?',
        answer: id,
        unit: 'cosas',
        topic: 'Pruebas',
        note: note,
        difficulty: difficulty,
      ),
    );

/// Un banco que no pide nada y anota lo que se recuerda.
class _RememberingBank extends FactsBank {
  _RememberingBank() : super(DirectusService());

  final remembered = <String>[];

  @override
  Future<void> remember(Iterable<Word> words) async {
    remembered.addAll([for (final w in words) w.id!]);
  }
}

void main() {
  group('modelo', () {
    test('es un juego aparte, gratis, con dificultad y sin combinarse', () {
      const c = GameCategory.moreOrLess;
      expect(c.code, 'MAS_O_MENOS');
      expect(c.section, isNull);
      expect(c.premium, isFalse);
      expect(c.facts, isTrue);
      expect(GameCategory.themed, isNot(contains(c)));
      expect(GameCategory.byCode('MAS_O_MENOS'), c);
      const config = GameConfig(category: c, wordSource: WordSource.random);
      expect(config.moreOrLess, isTrue);
      expect(config.smallPool, isTrue);
      expect(config.usesDifficulty, isTrue);
      expect(FactsBank.freeForNow, isTrue);
    });

    test('el turno dura como mínimo 1:30 y como máximo 3:00', () {
      GameConfig at(int seconds) => GameConfig(
        category: GameCategory.moreOrLess,
        wordSource: WordSource.random,
        turnDuration: Duration(seconds: seconds),
      );
      expect((at(60).turnMin, at(60).turnMax, at(60).turnStep), (90, 180, 30));
      expect(at(30).validTurn, const Duration(seconds: 90));
      expect(at(60).validTurn, const Duration(seconds: 90));
      expect(at(130).validTurn, const Duration(seconds: 120));
      expect(at(600).validTurn, const Duration(seconds: 180));
      // En las demás categorías sigue de 30 a 90 segundos.
      const animals = GameConfig(category: GameCategory.animals);
      expect((animals.turnMin, animals.turnMax), (30, 90));
      // La partida rápida también dura 1:30, y la personalizada que le
      // sigue nunca menos.
      final quick = QuickGame.config(at(60));
      expect(quick.turnDuration, const Duration(seconds: 90));
      expect(quick.difficulty, Difficulty.mixed);
      expect(QuickGame.custom(quick).turnDuration.inSeconds, 90);
      expect(QuickGame.config(animals).turnDuration, GameConfig.quickTurn);
    });

    test('la respuesta se escribe para leerla de lejos', () {
      FactItem item(int n, [String? unit]) =>
          FactItem(id: '1', question: '¿?', answer: n, unit: unit);
      expect(item(8, 'patas').answerText, '8 patas');
      expect(item(1969).answerText, '1969');
      expect(item(3600, 'segundos').answerText, '3600 segundos');
      expect(item(42195, 'metros').answerText, '42.195 metros');
      expect(
        item(299792458, 'metros por segundo').answerText,
        '299.792.458 metros por segundo',
      );
      expect(item(1000000).answerText, '1.000.000');
    });

    test('lee el dato del servidor y descarta los que no sirven', () {
      expect(
        FactItem.fromJson({
          'id': 3,
          'pregunta': ' ¿Cuántas patas tiene una araña? ',
          'respuesta': 8,
          'unidad': 'patas',
          'dato_curioso': 'No son insectos.',
          'categoria': 'Animales',
          'dificultad': 'FACIL',
        })?.answerText,
        '8 patas',
      );
      expect(
        FactItem.fromJson({'id': 1, 'pregunta': '¿?', 'respuesta': '8'}),
        isNull,
      );
      expect(
        FactItem.fromJson({'id': 1, 'pregunta': '', 'respuesta': 8}),
        isNull,
      );
      expect(
        FactItem.fromJson({'id': 1, 'pregunta': '¿?', 'respuesta': 8.5}),
        isNull,
      );
    });
  });

  test('el juez recibe la respuesta solo en ¿Más o menos?', () {
    final state = const JudgeState(
      phase: JudgeState.playing,
      word: '¿Cuántas patas tiene una araña?',
      answer: '8 patas',
      words: [JudgeWord('¿Dato?', hit: true, answer: '1969')],
    ).toJson();
    expect(state['respuesta'], '8 patas');
    expect(
      (state['palabras'] as List).single,
      containsPair('respuesta', '1969'),
    );
    final normal = const JudgeState(
      phase: JudgeState.playing,
      word: 'Perro',
      words: [JudgeWord('Perro', hit: true)],
    ).toJson();
    // Así las partidas normales no cambian para el juez.
    expect(normal.containsKey('respuesta'), isFalse);
    expect(
      (normal['palabras'] as List).single.containsKey('respuesta'),
      isFalse,
    );
  });

  test('el video lleva el tema, la pregunta y la respuesta', () {
    final ass = VideoRenderer.buildSubtitles([
      const Caption(
        '¿Cuántas patas tiene una araña?',
        CaptionStyle.word,
        Duration.zero,
        Duration(seconds: 2),
        label: 'Animales',
        answer: '8 patas',
      ),
    ]);
    expect(
      ass,
      contains(
        r'{\fs40}Animales\N{\fs52}¿Cuántas patas tiene una araña?\N{\r}8 patas',
      ),
    );
  });

  group('banco de datos', () {
    late Directory dir;
    late List<Map<String, dynamic>> requests;
    var online = true;
    final facts = [
      for (var i = 1; i <= 6; i++)
        {
          'id': i,
          'pregunta': '¿Dato $i?',
          'respuesta': i * 10,
          'unidad': null,
          'dato_curioso': null,
          'categoria': 'Pruebas',
          'dificultad': 'FACIL',
        },
    ];

    FactsBank bank() => FactsBank(
      DirectusService(
        baseUrl: 'https://directus.test',
        client: MockClient((request) async {
          if (!online) throw const SocketException('sin red');
          expect(request.url.path, '/juego/datos');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requests.add(body);
          final excluded = (body['excluir'] as List).toSet();
          // Como la extensión: primero los no jugados.
          final data = [
            ...facts.where((f) => !excluded.contains(f['id'])),
            ...facts.where((f) => excluded.contains(f['id'])),
          ].take(body['n'] as int).toList();
          return http.Response.bytes(
            utf8.encode(jsonEncode({'data': data})),
            200,
          );
        }),
      ),
      historyDirectory: () async => dir,
    );

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('datos');
      requests = [];
      online = true;
    });
    tearDown(() => dir.delete(recursive: true));

    test('pide la dificultad elegida y los datos traen su respuesta', () async {
      final words = await bank().prepare(
        3,
        difficulty: Difficulty.easy,
        includePremium: true,
      );
      expect(words, hasLength(3));
      expect(requests.single['dificultad'], 'FACIL');
      expect(requests.single['incluir_premium'], isTrue);
      expect(words.every((w) => w.isFact && w.topic == 'Pruebas'), isTrue);
      // Mezclada no manda dificultad.
      await bank().prepare(
        3,
        difficulty: Difficulty.mixed,
        includePremium: false,
      );
      expect(requests.last.containsKey('dificultad'), isFalse);
    });

    test(
      'no se repiten: los que salieron en un turno quedan excluidos',
      () async {
        final first = await bank().prepare(3, includePremium: true);
        await bank().remember(first);
        final second = await bank().prepare(3, includePremium: true);
        expect(requests.last['excluir'], [
          for (final w in first) int.parse(w.id!),
        ]);
        expect(
          second
              .map((w) => w.id)
              .toSet()
              .intersection(first.map((w) => w.id).toSet()),
          isEmpty,
        );
        // Las palabras que no son datos no se anotan.
        await bank().remember([Word('Perro')]);
        expect(await bank().history(), hasLength(3));
      },
    );

    test('sin internet avisa que hace falta conexión', () async {
      online = false;
      await expectLater(
        bank().prepare(3, includePremium: true),
        throwsA(
          isA<FactsException>().having((e) => e.offline, 'offline', isTrue),
        ),
      );
    });

    test('si no alcanzan para los equipos, avisa', () async {
      facts.removeRange(1, facts.length);
      await expectLater(
        bank().prepare(3, includePremium: true, minimum: 2),
        throwsA(isA<FactsException>()),
      );
    });
  });

  group('partida', () {
    late ProviderContainer container;
    late _RememberingBank bank;
    GameController controller() =>
        container.read(gameControllerProvider.notifier);
    GameState state() => container.read(gameControllerProvider);

    setUp(() {
      bank = _RememberingBank();
      container = ProviderContainer(
        overrides: [factsBankProvider.overrideWithValue(bank)],
      );
      controller().configure(
        const GameConfig(
          category: GameCategory.moreOrLess,
          wordSource: WordSource.random,
          groups: [Group('A'), Group('B')],
          rounds: 2,
          turnDuration: Duration(seconds: 90),
          scoringMode: ScoringMode.perPhrase,
        ),
      );
      controller().startWithWords([for (var i = 1; i <= 40; i++) fact(i)]);
    });
    tearDown(() => container.dispose());

    test('más difícil, más puntos: Fácil 1, Normal 2 y Difícil 5, sin '
        'importar la puntuación', () {
      final easy = fact(1);
      final normal = fact(2, difficulty: 'NORMAL');
      final hard = fact(3, difficulty: 'DIFICIL');
      expect([easy.value, normal.value, hard.value], [1, 2, 5]);
      final turn = Turn(
        round: 1,
        groupIndex: 0,
        entries: [
          TurnEntry(easy, WordOutcome.hit),
          TurnEntry(normal, WordOutcome.hit),
          TurnEntry(hard, WordOutcome.hit),
          TurnEntry(fact(4, difficulty: 'DIFICIL'), WordOutcome.pass),
        ],
      );
      expect(turn.points(ScoringMode.perPhrase), 8);
      expect(turn.points(ScoringMode.perWord), 8);
      // El juez también ve cuánto vale cada uno.
      expect(ScoringMode.perPhrase.pointsOf(hard), 5);
      // Las palabras siguen igual.
      expect(ScoringMode.perWord.pointsOf(Word('El Rey León')), 3);
    });

    test('cada dato fácil acertado vale 1 punto y pasar no suma', () {
      final deck = state().currentDeck;
      // Las preguntas tienen muchas palabras, pero cada una vale 1.
      expect(deck.first.wordCount, greaterThan(3));
      controller().finishTurn(
        Turn(
          round: 1,
          groupIndex: 0,
          entries: [
            TurnEntry(deck[0], WordOutcome.hit),
            TurnEntry(deck[1], WordOutcome.pass),
            TurnEntry(deck[2], WordOutcome.hit),
          ],
        ),
      );
      expect(state().scores, [2, 0]);
      expect(state().lastTurn!.passed, [deck[1]]);
      // Lo que salió en el turno queda anotado para no repetirlo.
      expect(bank.remembered, [deck[0].id, deck[1].id, deck[2].id]);
    });

    test('un turno de 1:30 trae datos para un grupo rápido', () {
      expect(state().config.fastWordsPerTurn, 15);
      expect(state().decks.every((d) => d.length >= 15), isTrue);
    });

    test('con pocos datos se repiten, pero nunca dos seguidos', () {
      controller().startWithWords([for (var i = 1; i <= 4; i++) fact(i)]);
      for (final deck in state().decks) {
        expect(deck, hasLength(15));
        for (var i = 1; i < deck.length; i++) {
          expect(deck[i], isNot(deck[i - 1]));
        }
      }
    });
  });

  group('pantallas', () {
    testWidgets('el turno muestra el tema, la pregunta y la respuesta', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(2400, 1080);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: WordCard(
            word: fact(8),
            remaining: const Duration(seconds: 80),
            feedback: null,
            recording: false,
          ),
        ),
      );
      expect(find.byType(FactView), findsOneWidget);
      expect(find.text('PRUEBAS · 1 PUNTO'), findsOneWidget);
      expect(
        find.text('¿Cuántas cosas tiene el dato número 8?'),
        findsOneWidget,
      );
      expect(find.text('8 cosas'), findsOneWidget);
    });

    testWidgets('en el resultado se ve la respuesta y el dato curioso', (
      tester,
    ) async {
      var toggled = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TurnWordsPanel(
              entries: [
                TurnEntry(fact(8, note: 'Un dato curioso.'), WordOutcome.hit),
                TurnEntry(fact(9), WordOutcome.pass),
              ],
              mode: ScoringMode.perPhrase,
              onToggle: (i) => toggled = i,
            ),
          ),
        ),
      );
      expect(find.text('8 cosas'), findsOneWidget);
      expect(find.text('9 cosas'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      // Solo el que tiene dato curioso lleva el botón.
      expect(find.byTooltip('Dato curioso'), findsOneWidget);
      await tester.tap(find.byTooltip('Dato curioso'));
      await tester.pumpAndSettle();
      expect(find.text('Un dato curioso.'), findsOneWidget);
      expect(toggled, -1);
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      // Tocar la fila sigue corrigiendo la marca.
      await tester.tap(find.text('9 cosas'));
      expect(toggled, 1);
    });

    testWidgets('la configuración: sin Puntuación, con dificultad y turnos '
        'de 1:30 a 3:00', (tester) async {
      final container = await pumpConfig(
        tester,
        config: const GameConfig(
          category: GameCategory.moreOrLess,
          wordSource: WordSource.random,
          groups: [Group('A'), Group('B')],
          // Viene de una partida de 45 segundos.
          turnDuration: Duration(seconds: 45),
        ),
        store: MemoryConfigStore(
          const SavedConfig(
            groupNames: ['A', 'B'],
            rounds: 3,
            turnDuration: Duration(seconds: 60),
            wordsPerGroup: 10,
            scoringMode: ScoringMode.perWord,
            hitMode: HitMode.tilt,
            resolution: VideoResolution.hd,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Continuar'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Puntuación'), findsNothing);
      expect(find.text('Dificultad'), findsOneWidget);
      expect(find.text('Mezclada'), findsOneWidget);
      final time = tester.widget<NumberStepper>(
        find.descendant(
          of: find.widgetWithText(ConfigRow, 'Tiempo por turno'),
          matching: find.byType(NumberStepper),
        ),
      );
      expect((time.value, time.min, time.max, time.step), (90, 90, 180, 30));
      expect(find.text('1:30'), findsOneWidget);
      await tapContinue(tester);
      final config = container.read(gameControllerProvider).config;
      expect(config.moreOrLess, isTrue);
      expect(config.scoringMode, ScoringMode.perPhrase);
      expect(config.turnDuration, const Duration(seconds: 90));
      expect(config.difficulty, Difficulty.mixed);
    });
  });
}
