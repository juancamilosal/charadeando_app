import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Lo desbloqueado, en memoria.
class MemoryPremiumStore extends PremiumStore {
  MemoryPremiumStore([this.saved = const PremiumAccess()]);

  PremiumAccess saved;

  @override
  Future<PremiumAccess> load() async => saved;

  @override
  Future<void> save(PremiumAccess access) async => saved = access;

  @override
  Future<String> deviceId() async => 'celular-de-prueba';
}

/// Google Play de mentira: Premium a $14.900 y cada categoría a $3.900.
/// [available] dice si se puede comprar y [send] manda una compra como si
/// llegara de la tienda.
class FakeBilling implements PremiumBilling {
  FakeBilling({this.available = true});

  final bool available;
  final _events = StreamController<BillingEvent>.broadcast();

  /// Lo que se intentó comprar: null es Premium.
  final bought = <String?>[];
  int restores = 0;

  int get buys => bought.length;

  void send(BillingEvent event) => _events.add(event);

  @override
  Stream<BillingEvent> get events => _events.stream;

  @override
  Future<StorePrice?> price({String? category}) async {
    if (!available) return null;
    return category == null
        ? const StorePrice(r'$14.900', 14900, 'COP', symbol: r'$')
        : const StorePrice(r'$3.900', 3900, 'COP', symbol: r'$');
  }

  @override
  Future<bool> buy({String? category}) async {
    bought.add(category);
    return available;
  }

  @override
  Future<void> restore() async => restores++;
}

/// No guarda el fondo en ningún archivo.
class _NoBackdropFile extends BackdropStore {
  @override
  Future<void> save(Backdrop backdrop) async {}
}

/// Códigos de mentira: FAMILIA abre todo y ANIME2026, Anime.
class FakeCodes extends PromoCodeService {
  FakeCodes({this.restored = const CodeUnlock(), this.offline = false});

  final redeemed = <(String, String)>[];

  /// Lo que devuelve "mis códigos": lo que este celular ya canjeó.
  final CodeUnlock restored;

  /// Sin internet: "mis códigos" falla.
  final bool offline;

  /// Celulares que pidieron "mis códigos".
  final restores = <String>[];

  @override
  Future<CodeUnlock> restore({required String device}) async {
    restores.add(device);
    if (offline) throw const CodeException('No hay conexión.');
    return restored;
  }

  @override
  Future<CodeUnlock> redeem(String code, {required String device}) async {
    redeemed.add((code, device));
    return switch (code.toUpperCase()) {
      'FAMILIA' => const CodeUnlock(all: true),
      'ANIME2026' => const CodeUnlock(categories: {'ANIME'}),
      'VIEJO' => throw const CodeException('Este código ya venció.'),
      _ => throw const CodeException('Código no válido.'),
    };
  }
}

void main() {
  group('PremiumAccess', () {
    test('las categorías gratis siempre se juegan; las de pago, con Premium '
        'o con su código', () {
      expect(GameCategory.animals.premium, isFalse);
      expect(GameCategory.anime.premium, isTrue);
      const none = PremiumAccess();
      expect(none.premium, isFalse);
      expect(none.unlocks(GameCategory.animals), isTrue);
      expect(none.unlocks(GameCategory.anime), isFalse);

      const anime = PremiumAccess(codeCategories: {'ANIME'});
      expect(anime.premium, isFalse);
      expect(anime.unlocks(GameCategory.anime), isTrue);
      expect(anime.unlocks(GameCategory.footballers), isFalse);

      for (final all in const [
        PremiumAccess(purchased: true),
        PremiumAccess(codeAll: true),
      ]) {
        expect(all.premium, isTrue);
        expect(GameCategory.paid.every(all.unlocks), isTrue);
      }
    });

    test('se guarda y se lee igual', () {
      const access = PremiumAccess(
        purchased: true,
        codeCategories: {'FUTBOLISTAS', 'ANIME'},
        boughtCategories: {'NAVIDAD'},
      );
      final back = PremiumAccess.fromJson(
        jsonDecode(jsonEncode(access.toJson())) as Map<String, dynamic>,
      );
      expect(back.purchased, isTrue);
      expect(back.codeAll, isFalse);
      expect(back.codeCategories, {'ANIME', 'FUTBOLISTAS'});
      expect(back.boughtCategories, {'NAVIDAD'});
      expect(back.unlocks(GameCategory.christmas), isTrue);
    });
  });

  test(
    'PremiumStore guarda lo desbloqueado y el mismo id del celular',
    () async {
      final dir = await Directory.systemTemp.createTemp('premium');
      addTearDown(() => dir.delete(recursive: true));
      final store = PremiumStore(directory: () async => dir);
      expect((await store.load()).premium, isFalse);
      final id = await store.deviceId();
      expect(id.length, greaterThanOrEqualTo(8));
      await store.save(const PremiumAccess(codeAll: true));
      expect((await store.load()).premium, isTrue);
      // Guardar no cambia el id.
      expect(await PremiumStore(directory: () async => dir).deviceId(), id);
    },
  );

  group('PremiumStore.deviceId', () {
    Future<Directory> tempDir() async {
      final dir = await Directory.systemTemp.createTemp('dispositivo');
      addTearDown(() => dir.delete(recursive: true));
      return dir;
    }

    test(
      'con ANDROID_ID manda su SHA-256, el mismo aunque se reinstale',
      () async {
        final dir = await tempDir();
        final store = PremiumStore(
          directory: () async => dir,
          androidId: () async => 'abc123',
        );
        final id = await store.deviceId();
        expect(id, PremiumStore.hashAndroidId('abc123'));
        expect(id, isNot(contains('abc123')));
        expect(RegExp(r'^[A-Za-z0-9_-]{8,100}$').hasMatch(id), isTrue);
        // Otra instalación (otra carpeta, sin nada guardado) da el mismo.
        final other = await tempDir();
        expect(
          await PremiumStore(
            directory: () async => other,
            androidId: () async => 'abc123',
          ).deviceId(),
          id,
        );
        // Es el SHA-256 de "charadeando:" + ANDROID_ID, en hexadecimal.
        expect(
          id,
          'c9390c8cf7bb6fb9043db4e5a76096ad35b15ea11d58bc22a78b22a3181aa879',
        );
      },
    );

    for (final (name, read) in <(String, Future<String?> Function())>[
      ('null', () async => null),
      ('vacío', () async => '  '),
      ('con error', () async => throw Exception('sin canal')),
    ]) {
      test(
        'si el ANDROID_ID viene $name usa el de respaldo, siempre el mismo',
        () async {
          final dir = await tempDir();
          final store = PremiumStore(
            directory: () async => dir,
            androidId: read,
          );
          final id = await store.deviceId();
          expect(id, hasLength(24));
          expect(await store.deviceId(), id);
        },
      );
    }
  });

  group('PromoCodeService', () {
    PromoCodeService service(int status, Object body, [List<String>? log]) =>
        PromoCodeService(
          baseUrl: 'https://directus.test',
          client: MockClient((request) async {
            log?.add('${request.url} ${request.body}');
            return http.Response.bytes(
              utf8.encode(jsonEncode(body)),
              status,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );

    test('canjea un código que abre todo, con el id del celular', () async {
      final log = <String>[];
      final unlock = await service(200, {
        'data': {'todo': true, 'categorias': <String>[]},
      }, log).redeem(' familia ', device: 'abc12345');
      expect(unlock.all, isTrue);
      expect(log.single, contains('/juego/canjear'));
      expect(log.single, contains('"codigo":"familia"'));
      expect(log.single, contains('"dispositivo":"abc12345"'));
    });

    test('canjea un código de algunas categorías', () async {
      final unlock = await service(200, {
        'data': {
          'todo': false,
          'categorias': ['ANIME', 'futbolistas'],
        },
      }).redeem('X1Y2Z3', device: 'abc12345');
      expect(unlock.all, isFalse);
      expect(unlock.categories, {'ANIME', 'FUTBOLISTAS'});
    });

    test('pide lo que abren los códigos ya canjeados', () async {
      final log = <String>[];
      final unlock = await service(200, {
        'data': {
          'todo': false,
          'categorias': ['ANIME'],
        },
      }, log).restore(device: 'abc12345');
      expect(unlock.categories, {'ANIME'});
      expect(unlock.isEmpty, isFalse);
      expect(log.single, contains('/juego/mis-codigos'));
      expect(log.single, contains('"dispositivo":"abc12345"'));
      final none = await service(200, {
        'data': {'todo': false, 'categorias': <String>[]},
      }).restore(device: 'abc12345');
      expect(none.isEmpty, isTrue);
    });

    test('muestra el mensaje del servidor cuando no sirve', () async {
      await expectLater(
        service(409, {
          'errors': [
            {'message': 'Este código ya se usó todas las veces que permite.'},
          ],
        }).redeem('USADO', device: 'abc12345'),
        throwsA(
          isA<CodeException>().having(
            (e) => e.message,
            'message',
            'Este código ya se usó todas las veces que permite.',
          ),
        ),
      );
    });

    test('sin internet avisa', () async {
      final offline = PromoCodeService(
        baseUrl: 'https://directus.test',
        client: MockClient((_) async => throw const SocketException('sin red')),
      );
      await expectLater(
        offline.redeem('FAMILIA', device: 'abc12345'),
        throwsA(
          isA<CodeException>().having(
            (e) => e.message,
            'message',
            contains('No hay conexión'),
          ),
        ),
      );
    });
  });

  group('PremiumController', () {
    ProviderContainer container({
      required FakeBilling billing,
      MemoryPremiumStore? store,
      FakeCodes? codes,
    }) {
      final c = ProviderContainer(
        overrides: [
          premiumBillingProvider.overrideWithValue(billing),
          premiumStoreProvider.overrideWithValue(store ?? MemoryPremiumStore()),
          promoCodeServiceProvider.overrideWithValue(codes ?? FakeCodes()),
          backdropStoreProvider.overrideWithValue(_NoBackdropFile()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('al abrir lee lo guardado y busca compras en Google Play', () async {
      final billing = FakeBilling();
      final c = container(
        billing: billing,
        store: MemoryPremiumStore(
          const PremiumAccess(codeCategories: {'ANIME'}),
        ),
      );
      c.read(premiumProvider);
      await pumpEventQueue();
      expect(c.read(premiumProvider).codeCategories, {'ANIME'});
      expect(billing.restores, 1);
      expect(
        c.read(lockedCategoriesProvider),
        isNot(contains(GameCategory.anime)),
      );
      expect(
        c.read(lockedCategoriesProvider),
        contains(GameCategory.footballers),
      );
    });

    test(
      'al abrir sin nada guardado recupera los códigos de este celular',
      () async {
        final codes = FakeCodes(restored: const CodeUnlock(all: true));
        final store = MemoryPremiumStore();
        final c = container(billing: FakeBilling(), store: store, codes: codes);
        c.read(premiumProvider);
        await pumpEventQueue();
        expect(codes.restores, ['celular-de-prueba']);
        expect(c.read(premiumUnlockedProvider), isTrue);
        expect(store.saved.codeAll, isTrue);
      },
    );

    test('con algo guardado no pide los códigos al abrir', () async {
      final codes = FakeCodes(restored: const CodeUnlock(all: true));
      final c = container(
        billing: FakeBilling(),
        store: MemoryPremiumStore(
          const PremiumAccess(codeCategories: {'ANIME'}),
        ),
        codes: codes,
      );
      c.read(premiumProvider);
      await pumpEventQueue();
      expect(codes.restores, isEmpty);
      expect(c.read(premiumUnlockedProvider), isFalse);
    });

    test(
      'sin internet al abrir no pasa nada; se puede intentar después',
      () async {
        final codes = FakeCodes(offline: true);
        final billing = FakeBilling();
        final c = container(billing: billing, codes: codes);
        c.read(premiumProvider);
        await pumpEventQueue();
        expect(codes.restores, hasLength(1));
        expect(c.read(premiumProvider).nothing, isTrue);
        // Igual busca las compras de Google Play.
        expect(billing.restores, 1);
      },
    );

    test('una compra de Google Play desbloquea todo y se guarda', () async {
      final billing = FakeBilling();
      final store = MemoryPremiumStore();
      final c = container(billing: billing, store: store);
      expect(c.read(premiumUnlockedProvider), isFalse);
      await pumpEventQueue();
      expect(await c.read(premiumProvider.notifier).buy(), isTrue);
      expect(billing.buys, 1);
      billing.send(const BillingEvent(BillingStatus.owned));
      await pumpEventQueue();
      expect(c.read(premiumUnlockedProvider), isTrue);
      expect(c.read(lockedCategoriesProvider), isEmpty);
      expect(store.saved.purchased, isTrue);
      // Y la app se viste de Oro.
      expect(c.read(backdropProvider), Backdrop.oro);
    });

    test('una categoría comprada suelta abre solo esa y se guarda', () async {
      final billing = FakeBilling();
      final store = MemoryPremiumStore();
      final c = container(billing: billing, store: store);
      expect(c.read(lockedCategoriesProvider), contains(GameCategory.anime));
      await pumpEventQueue();
      await c.read(premiumProvider.notifier).buy(category: 'ANIME');
      expect(billing.bought, ['ANIME']);
      billing.send(const BillingEvent(BillingStatus.owned, category: 'ANIME'));
      await pumpEventQueue();
      expect(c.read(premiumUnlockedProvider), isFalse);
      expect(
        c.read(lockedCategoriesProvider),
        isNot(contains(GameCategory.anime)),
      );
      expect(
        c.read(lockedCategoriesProvider),
        contains(GameCategory.christmas),
      );
      expect(store.saved.boughtCategories, {'ANIME'});
    });

    test('ya comprado no vuelve a buscar compras al abrir', () async {
      final billing = FakeBilling();
      final c = container(
        billing: billing,
        store: MemoryPremiumStore(const PremiumAccess(purchased: true)),
      );
      c.read(premiumProvider);
      await pumpEventQueue();
      expect(c.read(premiumUnlockedProvider), isTrue);
      expect(billing.restores, 0);
    });

    test('los códigos suman lo que abren y se guardan', () async {
      final store = MemoryPremiumStore();
      final codes = FakeCodes();
      final c = container(billing: FakeBilling(), store: store, codes: codes);
      await pumpEventQueue();
      final controller = c.read(premiumProvider.notifier);

      await controller.redeem('ANIME2026');
      // Abrir una sola categoría no cambia el fondo.
      expect(c.read(backdropProvider), Backdrop.standard);
      expect(codes.redeemed.single, ('ANIME2026', 'celular-de-prueba'));
      expect(c.read(premiumUnlockedProvider), isFalse);
      expect(
        c.read(lockedCategoriesProvider),
        isNot(contains(GameCategory.anime)),
      );
      expect(store.saved.codeCategories, {'ANIME'});

      await expectLater(
        controller.redeem('VIEJO'),
        throwsA(isA<CodeException>()),
      );
      expect(c.read(premiumUnlockedProvider), isFalse);

      await controller.redeem('familia');
      expect(c.read(premiumUnlockedProvider), isTrue);
      expect(c.read(backdropProvider), Backdrop.oro);
      expect(store.saved.codeAll, isTrue);
      expect(store.saved.codeCategories, {'ANIME'});
    });
  });

  test('los productos de Google Play', () {
    expect(PlayBilling.productId(null), 'charadeando_premium');
    expect(
      PlayBilling.productId('DEPORTISTAS_FAMOSOS'),
      'categoria_deportistas_famosos',
    );
    expect(PlayBilling.categoryOf('charadeando_premium'), isNull);
    expect(PlayBilling.categoryOf('categoria_anime'), 'ANIME');
    expect(PlayBilling.categoryOf('otra_cosa'), '');
  });
}
