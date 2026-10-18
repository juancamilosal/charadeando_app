import 'dart:async';
import 'dart:io';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/router.dart';
import 'package:charadeando_app/screens/auto_words_screen.dart';
import 'package:charadeando_app/screens/category_screen.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:charadeando_app/widgets/photo_mime_view.dart';
import 'package:charadeando_app/widgets/tv_turn_view.dart';
import 'package:charadeando_app/widgets/word_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../services/premium_test.dart';
import 'my_categories_test.dart' show MemoryCustomStore;

/// Un banco de Fotomímica de mentira: avisa el progreso cuando se le pide
/// y termina con [result] o con [error].
class _FakePhotoBank extends PhotoMimeBank {
  _FakePhotoBank() : super(DirectusService());

  final requests = <(int, bool, int)>[];
  void Function(int, int)? progress;
  final done = Completer<List<Word>>();

  @override
  Future<List<Word>> prepare(
    int count, {
    required bool includePremium,
    int minimum = 1,
    void Function(int ready, int total)? onProgress,
  }) {
    requests.add((count, includePremium, minimum));
    progress = onProgress;
    return done.future;
  }
}

Word photo(String name) => Word(
  name,
  category: 'FOTOMIMICA',
  id: name,
  image: '/no/existe/$name.webp',
);

void main() {
  group('modelo', () {
    test('Fotomímica es gratis, va aparte y no se combina', () {
      const c = GameCategory.photoMime;
      expect(c.code, 'FOTOMIMICA');
      expect(c.section, isNull);
      expect(c.premium, isFalse);
      expect(c.photos, isTrue);
      expect(GameCategory.themed, isNot(contains(c)));
      expect(GameCategory.byCode('FOTOMIMICA'), c);
    });

    test('no tiene dificultad, ni en la partida rápida', () {
      const config = GameConfig(
        category: GameCategory.photoMime,
        wordSource: WordSource.random,
        difficulty: Difficulty.hard,
      );
      expect(config.photoMime, isTrue);
      expect(config.usesDifficulty, isFalse);
      expect(QuickGame.config(config).difficulty, isNull);
      expect(
        const GameConfig(
          category: GameCategory.animals,
          wordSource: WordSource.random,
        ).photoMime,
        isFalse,
      );
    });
  });

  group('sección en Categorías', () {
    Future<void> pump(WidgetTester tester, {PremiumAccess? access}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          customCategoryStoreProvider.overrideWithValue(MemoryCustomStore()),
          clockProvider.overrideWithValue(() => DateTime(2026, 12, 10)),
          allSeasonsProvider.overrideWithValue(false),
          premiumBillingProvider.overrideWithValue(FakeBilling()),
          premiumStoreProvider.overrideWithValue(
            MemoryPremiumStore(access ?? const PremiumAccess()),
          ),
          promoCodeServiceProvider.overrideWithValue(FakeCodes()),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: Routes.categories,
        routes: [
          GoRoute(
            path: Routes.categories,
            builder: (_, _) => const CategoryScreen(),
          ),
          GoRoute(path: Routes.config, builder: (_, _) => const Text('Config')),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('va antes de Mis categorías y, gratis por ahora, sin aviso '
        'de Premium', (tester) async {
      await pump(tester);
      expect(find.byType(PhotoMimeSection), findsOneWidget);
      expect(find.text('Fotomímica'), findsWidgets);
      expect(find.text('Más juegos'), findsOneWidget);
      expect(find.text('NUEVO JUEGO'), findsOneWidget);
      // Va después de las categorías, justo antes de "Mis categorías".
      expect(
        tester.getTopLeft(find.byType(PhotoMimeSection)).dy,
        greaterThan(tester.getTopLeft(find.text('Especiales')).dy),
      );
      expect(
        tester.getTopLeft(find.byType(PhotoMimeSection)).dy,
        lessThan(tester.getTopLeft(find.text('Mis categorías')).dy),
      );
      expect(PhotoMimeBank.freeForNow, isTrue);
      expect(find.text('Más objetos con Premium'), findsNothing);
    });

    testWidgets('con Premium no hay aviso y la tarjeta abre cómo jugar', (
      tester,
    ) async {
      await pump(tester, access: const PremiumAccess(purchased: true));
      expect(find.text('Más objetos con Premium'), findsNothing);

      final card = find.descendant(
        of: find.byType(PhotoMimeSection),
        matching: find.text('Jugar'),
      );
      await tester.ensureVisible(card);
      await tester.pump();
      await tester.tap(card);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Personalizada'), findsOneWidget);
    });
  });

  group('preparar la partida', () {
    Future<(ProviderContainer, _FakePhotoBank)> pump(
      WidgetTester tester, {
      bool premium = false,
    }) async {
      final bank = _FakePhotoBank();
      final container = ProviderContainer(
        overrides: [
          photoMimeBankProvider.overrideWithValue(bank),
          premiumUnlockedProvider.overrideWithValue(premium),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(gameControllerProvider.notifier)
          .configure(
            const GameConfig(
              category: GameCategory.photoMime,
              wordSource: WordSource.random,
              groups: [Group('Tigres'), Group('Águilas')],
              rounds: 1,
              turnDuration: Duration(seconds: 30),
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: Routes.autoWords,
              routes: [
                GoRoute(
                  path: Routes.autoWords,
                  builder: (_, _) => const AutoWordsScreen(),
                ),
                GoRoute(
                  path: Routes.turn,
                  builder: (_, _) => const Text('Turno'),
                ),
                GoRoute(
                  path: Routes.config,
                  builder: (_, _) => const Text('Config'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      return (container, bank);
    }

    testWidgets('muestra "Preparando imágenes…" con el progreso y empieza '
        'cuando todas están listas', (tester) async {
      final (container, bank) = await pump(tester);
      expect(find.text('Fotomímica'), findsOneWidget);
      expect(find.text('Preparando imágenes…'), findsOneWidget);
      // 2 equipos × 1 ronda × (30 s / 3) = 20 objetos; por ahora, todos
      // gratis, también los de Premium.
      expect(bank.requests.single, (20, true, 2));

      bank.progress!(3, 20);
      await tester.pump();
      expect(find.text('3 de 20'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.15, 0.001),
      );
      expect(find.text('Turno'), findsNothing);

      bank.done.complete([for (var i = 0; i < 20; i++) photo('Objeto $i')]);
      await tester.pumpAndSettle();
      expect(find.text('Turno'), findsOneWidget);
      final decks = container.read(gameControllerProvider).decks;
      expect(decks.expand((d) => d), hasLength(20));
      expect(decks.expand((d) => d).every((w) => w.image != null), isTrue);
    });

    testWidgets('con Premium pide también los objetos de pago', (tester) async {
      final (_, bank) = await pump(tester, premium: true);
      expect(bank.requests.single.$2, isTrue);
    });

    testWidgets('sin internet lo dice y no deja empezar', (tester) async {
      final (container, bank) = await pump(tester);
      bank.done.completeError(PhotoMimeException.noConnection);
      await tester.pumpAndSettle();
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.textContaining('necesita internet'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Turno'), findsNothing);
      expect(container.read(gameControllerProvider).decks, isEmpty);
    });
  });

  group('turno', () {
    late Directory dir;
    late String image;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('fotomimica_turno');
      image = '${dir.path}/taladro.png';
      // Un PNG de 1×1.
      await File(image).writeAsBytes(const [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, //
        0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
        0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63,
        0xF8, 0xCF, 0xC0, 0xF0, 0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89,
        0x99, 0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
        0xAE, 0x42, 0x60, 0x82,
      ]);
    });
    tearDown(() => dir.delete(recursive: true));

    Word taladro() => Word('Taladro', category: 'FOTOMIMICA', image: image);

    testWidgets('la foto se ve grande sobre fondo oscuro y el nombre, '
        'pequeño, debajo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WordCard(
            word: taladro(),
            remaining: const Duration(seconds: 42),
            feedback: null,
            recording: false,
          ),
        ),
      );
      final view = find.byType(PhotoMimeView);
      expect(view, findsOneWidget);
      final picture = find.descendant(of: view, matching: find.byType(Image));
      expect(tester.widget<Image>(picture).fit, BoxFit.contain);
      // Ocupa casi toda la pantalla.
      expect(
        tester.getSize(picture).height,
        greaterThan(tester.getSize(find.byType(WordCard)).height * 0.7),
      );
      final name = tester.widget<Text>(find.text('Taladro'));
      expect(name.style!.fontSize, lessThan(30));
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('al marcar se ve "¡Correcto!" en vez de la foto', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WordCard(
            word: taladro(),
            remaining: const Duration(seconds: 42),
            feedback: WordOutcome.hit,
            recording: false,
          ),
        ),
      );
      expect(find.byType(PhotoMimeView), findsNothing);
      expect(find.text('¡Correcto!'), findsOneWidget);
    });

    testWidgets('en el Modo TV también se ve la foto con los botones del '
        'juez', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TvTurnView(
            word: taladro(),
            remaining: const Duration(seconds: 30),
            feedback: null,
            title: 'Turno de Tigres',
            onPass: () {},
            onHit: () {},
          ),
        ),
      );
      expect(find.byType(PhotoMimeView), findsOneWidget);
      expect(find.text('Taladro'), findsOneWidget);
      expect(find.text('Pasar'), findsOneWidget);
      expect(find.text('Turno de Tigres'), findsOneWidget);
    });

    testWidgets('las palabras siguen como siempre', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WordCard(
            word: Word('Jirafa'),
            remaining: const Duration(seconds: 42),
            feedback: null,
            recording: false,
          ),
        ),
      );
      expect(find.byType(PhotoMimeView), findsNothing);
      expect(find.text('Jirafa'), findsOneWidget);
    });
  });
}
