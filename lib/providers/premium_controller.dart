import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'providers.dart';

/// Lo desbloqueado: Premium (comprado en Google Play o con un código) y las
/// categorías sueltas, compradas o abiertas con códigos. Se guarda en el
/// celular.
class PremiumController extends Notifier<PremiumAccess> {
  final _events = StreamController<BillingEvent>.broadcast();

  /// Lo que pasa con las compras, para avisar en pantalla.
  Stream<BillingEvent> get events => _events.stream;

  @override
  PremiumAccess build() {
    final billing = ref.watch(premiumBillingProvider);
    final subscription = billing.events.listen(_onBilling);
    ref.onDispose(() {
      subscription.cancel();
      _events.close();
    });
    _load(billing);
    return const PremiumAccess();
  }

  PremiumStore get _store => ref.read(premiumStoreProvider);

  Future<void> _load(PremiumBilling billing) async {
    final saved = await _store.load();
    // Lo que llegó mientras se leía (una compra) no se pierde.
    state = saved.merge(state);
    // Si se reinstaló la app, las compras vuelven solas.
    if (!state.purchased) await billing.restore();
  }

  Future<void> _onBilling(BillingEvent event) async {
    final category = event.category;
    if (event.owned) {
      final before = state;
      state = category == null
          ? state.copyWith(purchased: true)
          : state.copyWith(
              boughtCategories: {...state.boughtCategories, category},
            );
      if (state.purchased != before.purchased ||
          state.boughtCategories.length != before.boughtCategories.length) {
        await _store.save(state);
      }
    }
    if (!_events.isClosed) _events.add(event);
  }

  /// Abre la ventana de pago de Google Play: Premium, o la categoría
  /// [category] suelta. Falso si no está disponible.
  Future<bool> buy({String? category}) =>
      ref.read(premiumBillingProvider).buy(category: category);

  /// Busca en Google Play las compras ya hechas.
  Future<void> restore() => ref.read(premiumBillingProvider).restore();

  /// Canjea [code]. Lanza [CodeException] si no sirve.
  Future<CodeUnlock> redeem(String code) async {
    final device = await _store.deviceId();
    final unlock = await ref
        .read(promoCodeServiceProvider)
        .redeem(code, device: device);
    state = state.copyWith(
      codeAll: state.codeAll || unlock.all,
      codeCategories: {...state.codeCategories, ...unlock.categories},
    );
    await _store.save(state);
    return unlock;
  }
}
