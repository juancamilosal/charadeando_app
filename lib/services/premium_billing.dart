import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'error_reporter.dart';

/// Cómo terminó una compra.
enum BillingStatus {
  /// Quedó comprado (una compra nueva, restaurada o un código de Google
  /// Play canjeado).
  owned,

  /// La compra falló.
  failed,

  /// La persona cerró la ventana de pago sin comprar.
  canceled,
}

/// Una compra que llega de la tienda: Premium ([category] null) o una
/// categoría suelta (su código, como `ANIME`).
class BillingEvent {
  const BillingEvent(this.status, {this.category});

  final BillingStatus status;
  final String? category;

  bool get owned => status == BillingStatus.owned;
}

/// Un precio de la tienda: el texto listo para mostrar ("$14.900") y el
/// valor, para comparar.
class StorePrice {
  const StorePrice(this.text, this.amount, this.currency, {this.symbol = ''});

  final String text;
  final double amount;
  final String currency;
  final String symbol;
}

/// Las compras de pago único en la tienda: Premium (todo) o una categoría
/// suelta. En cada método, [category] null es Premium.
abstract interface class PremiumBilling {
  /// Las compras que llegan de la tienda, también al restaurar.
  Stream<BillingEvent> get events;

  /// Precio, o null si la tienda no está disponible o no tiene el producto.
  Future<StorePrice?> price({String? category});

  /// Abre la ventana de pago. Falso si la tienda no está disponible.
  Future<bool> buy({String? category});

  /// Pide a la tienda las compras ya hechas; llegan por [events].
  Future<void> restore();
}

/// Productos "integrados en la aplicación" de pago único en Google Play:
/// `charadeando_premium` y uno por categoría de pago,
/// `categoria_<código en minúsculas>` (`categoria_anime`).
class PlayBilling implements PremiumBilling {
  PlayBilling({required this.categories});

  static const premiumId = 'charadeando_premium';
  static const _categoryPrefix = 'categoria_';

  /// Códigos de las categorías que se venden sueltas.
  final Iterable<String> categories;

  /// El producto de Premium o de una categoría.
  static String productId(String? category) => category == null
      ? premiumId
      : '$_categoryPrefix${category.toLowerCase()}';

  /// La categoría de un producto (null es Premium), o '' si no es nuestro.
  static String? categoryOf(String productId) {
    if (productId == premiumId) return null;
    if (productId.startsWith(_categoryPrefix)) {
      return productId.substring(_categoryPrefix.length).toUpperCase();
    }
    return '';
  }

  final InAppPurchase _store = InAppPurchase.instance;
  Future<Map<String, ProductDetails>>? _products;

  Future<Map<String, ProductDetails>> _load() => _products ??= () async {
    try {
      if (!await _store.isAvailable()) {
        _products = null;
        return <String, ProductDetails>{};
      }
      final response = await _store.queryProductDetails({
        premiumId,
        for (final c in categories) productId(c),
      });
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('[Premium] Play no tiene: ${response.notFoundIDs}');
      }
      return {for (final p in response.productDetails) p.id: p};
    } on Object catch (e) {
      debugPrint('[Premium] No se pudo consultar Play: $e');
      // Se vuelve a intentar la próxima vez.
      _products = null;
      return <String, ProductDetails>{};
    }
  }();

  @override
  Stream<BillingEvent> get events =>
      _store.purchaseStream.asyncExpand((purchases) async* {
        for (final purchase in purchases) {
          final category = categoryOf(purchase.productID);
          if (category == '') continue;
          // Google devuelve las compras que no se confirman en 3 días.
          if (purchase.pendingCompletePurchase) {
            await _store.completePurchase(purchase);
          }
          if (purchase.status == PurchaseStatus.error) {
            ErrorReporter.instance.report(
              purchase.error ?? 'Compra fallida',
              null,
              reason: 'Compra ${purchase.productID}',
            );
          }
          final status = switch (purchase.status) {
            PurchaseStatus.purchased ||
            PurchaseStatus.restored => BillingStatus.owned,
            PurchaseStatus.error => BillingStatus.failed,
            PurchaseStatus.canceled => BillingStatus.canceled,
            PurchaseStatus.pending => null,
          };
          if (status != null) yield BillingEvent(status, category: category);
        }
      });

  @override
  Future<StorePrice?> price({String? category}) async {
    final product = (await _load())[productId(category)];
    if (product == null) return null;
    return StorePrice(
      product.price,
      product.rawPrice,
      product.currencyCode,
      symbol: product.currencySymbol,
    );
  }

  @override
  Future<bool> buy({String? category}) async {
    final product = (await _load())[productId(category)];
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
  Future<StorePrice?> price({String? category}) async => null;

  @override
  Future<bool> buy({String? category}) async => false;

  @override
  Future<void> restore() async {}
}

/// Google Play en Android, con las categorías de pago [categories]; en las
/// pruebas y en otros sistemas, sin tienda.
PremiumBilling defaultPremiumBilling(Iterable<String> categories) =>
    !Platform.environment.containsKey('FLUTTER_TEST') && Platform.isAndroid
    ? PlayBilling(categories: categories)
    : NoBilling();
