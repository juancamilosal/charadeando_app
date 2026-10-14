import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Lo que pasa con una compra de Premium.
enum BillingEvent {
  /// Quedó comprado (una compra nueva, restaurada o un código de Google
  /// Play canjeado).
  owned,

  /// La compra falló.
  failed,

  /// La persona cerró la ventana de pago sin comprar.
  canceled,
}

/// La compra de Premium en la tienda (pago único).
abstract interface class PremiumBilling {
  /// Las compras que llegan de la tienda, también al restaurar.
  Stream<BillingEvent> get events;

  /// Precio con su moneda, como lo da la tienda ("$14.900"), o null si la
  /// tienda no está disponible.
  Future<String?> price();

  /// Abre la ventana de pago. Falso si la tienda no está disponible.
  Future<bool> buy();

  /// Pide a la tienda las compras ya hechas; llegan por [events].
  Future<void> restore();
}

/// Premium en Google Play, con el producto `charadeando_premium` (un
/// "producto integrado" de pago único creado en Play Console).
class PlayBilling implements PremiumBilling {
  static const productId = 'charadeando_premium';

  final InAppPurchase _store = InAppPurchase.instance;
  Future<ProductDetails?>? _product;

  Future<ProductDetails?> _load() => _product ??= () async {
    try {
      if (!await _store.isAvailable()) return null;
      final response = await _store.queryProductDetails({productId});
      if (response.productDetails.isEmpty) {
        debugPrint('[Premium] Play no encontró el producto $productId');
        // Se vuelve a intentar la próxima vez.
        _product = null;
        return null;
      }
      return response.productDetails.first;
    } on Object catch (e) {
      debugPrint('[Premium] No se pudo consultar Play: $e');
      _product = null;
      return null;
    }
  }();

  @override
  Stream<BillingEvent> get events =>
      _store.purchaseStream.asyncExpand((purchases) async* {
        for (final purchase in purchases) {
          if (purchase.productID != productId) continue;
          // Google cancela las compras que no se confirman en 3 días.
          if (purchase.pendingCompletePurchase) {
            await _store.completePurchase(purchase);
          }
          switch (purchase.status) {
            case PurchaseStatus.purchased:
            case PurchaseStatus.restored:
              yield BillingEvent.owned;
            case PurchaseStatus.error:
              yield BillingEvent.failed;
            case PurchaseStatus.canceled:
              yield BillingEvent.canceled;
            case PurchaseStatus.pending:
              break;
          }
        }
      });

  @override
  Future<String?> price() async => (await _load())?.price;

  @override
  Future<bool> buy() async {
    final product = await _load();
    if (product == null) return false;
    return _store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  @override
  Future<void> restore() async {
    try {
      if (await _store.isAvailable()) await _store.restorePurchases();
    } on Object catch (e) {
      debugPrint('[Premium] No se pudieron restaurar las compras: $e');
    }
  }
}

/// Sin tienda: en las pruebas y donde no hay Google Play.
class NoBilling implements PremiumBilling {
  @override
  Stream<BillingEvent> get events => const Stream.empty();

  @override
  Future<String?> price() async => null;

  @override
  Future<bool> buy() async => false;

  @override
  Future<void> restore() async {}
}

/// Google Play en Android; en las pruebas y en otros sistemas, sin tienda.
PremiumBilling defaultPremiumBilling() =>
    !Platform.environment.containsKey('FLUTTER_TEST') && Platform.isAndroid
    ? PlayBilling()
    : NoBilling();
