import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'providers.dart';

/// "Mis categorías" y la pestaña elegida en la pantalla de categorías. Se
/// leen del celular al empezar y se guardan en cada cambio.
class CustomCategoriesController extends AsyncNotifier<CustomCategoriesData> {
  @override
  Future<CustomCategoriesData> build() =>
      ref.read(customCategoryStoreProvider).load();

  CustomCategoriesData get _data => state.value ?? const CustomCategoriesData();

  Future<void> _update(CustomCategoriesData data) async {
    state = AsyncData(data);
    await ref.read(customCategoryStoreProvider).save(data);
  }

  Future<void> setTab(CategoryTab tab) => _update(_data.copyWith(tab: tab));

  /// Si se puede crear otra categoría (ver [CustomCategoryStore.freeLimit]).
  bool get canCreate {
    final limit = CustomCategoryStore.freeLimit;
    return limit == null ||
        ref.read(premiumUnlockedProvider) ||
        _data.categories.length < limit;
  }

  /// Crea la categoría si es nueva, o la reemplaza si ya existía.
  Future<void> save(CustomCategory category) {
    final list = [..._data.categories];
    final i = list.indexWhere((c) => c.id == category.id);
    if (i < 0) {
      list.add(category);
    } else {
      list[i] = category;
    }
    return _update(_data.copyWith(categories: list));
  }

  Future<void> delete(String id) => _update(
    _data.copyWith(
      categories: [
        for (final c in _data.categories)
          if (c.id != id) c,
      ],
    ),
  );

  /// Id para una categoría nueva.
  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
