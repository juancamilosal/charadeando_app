import 'dart:io';

import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CustomCategory family({List<String>? words}) => CustomCategory(
  id: 'f1',
  name: 'Mi familia',
  description: 'Tíos, primos y abuelos',
  colorIndex: 3,
  iconKey: 'family',
  words: words ?? ['Tía Rosa', 'Abuelo', 'El perro Toby'],
);

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('mis'));
  tearDown(() => dir.delete(recursive: true));

  test('guarda y lee las categorías y la pestaña', () async {
    final store = CustomCategoryStore(directory: () async => dir);
    expect((await store.load()).categories, isEmpty);

    await store.save(
      CustomCategoriesData(categories: [family()], tab: CategoryTab.mine),
    );
    final loaded = await store.load();
    expect(loaded.tab, CategoryTab.mine);
    final c = loaded.categories.single;
    expect(c.name, 'Mi familia');
    expect(c.description, 'Tíos, primos y abuelos');
    expect(c.colorIndex, 3);
    expect(c.iconKey, 'family');
    expect(c.words, ['Tía Rosa', 'Abuelo', 'El perro Toby']);
  });

  test('crear, editar y borrar con el controlador', () async {
    final store = CustomCategoryStore(directory: () async => dir);
    final container = ProviderContainer(
      overrides: [customCategoryStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(customCategoriesProvider.notifier);
    await container.read(customCategoriesProvider.future);

    await notifier.save(family());
    await notifier.save(
      CustomCategory(id: 'o1', name: 'La oficina', words: const ['Jefe']),
    );
    expect((await store.load()).categories.map((c) => c.name), [
      'Mi familia',
      'La oficina',
    ]);

    // Editar reemplaza la misma categoría, no crea otra.
    await notifier.save(family().copyWith(name: 'Familia Salazar'));
    final edited = await store.load();
    expect(edited.categories.map((c) => c.name), [
      'Familia Salazar',
      'La oficina',
    ]);

    await notifier.delete('f1');
    expect((await store.load()).categories.map((c) => c.name), ['La oficina']);

    await notifier.setTab(CategoryTab.mine);
    expect((await store.load()).tab, CategoryTab.mine);
  });

  group('palabras', () {
    test('no acepta repetidas, sin importar mayúsculas ni tildes', () {
      final result = CustomWords.add(
        ['Tía Rosa', 'Canción'],
        ['tia rosa', 'CANCION', 'Abuelo', 'abuelo', '  Tía   Rosa '],
      );
      expect(result.words, ['Tía Rosa', 'Canción', 'Abuelo']);
      expect(result.repeated, hasLength(4));
    });

    test('se pegan varias separadas por comas o saltos de línea', () {
      expect(
        CustomWords.parse('Pizza, Helado,\nAbuelo\n\n  Tía   Rosa ; Toby'),
        ['Pizza', 'Helado', 'Abuelo', 'Tía Rosa', 'Toby'],
      );
      expect(CustomWords.parse(' , \n '), isEmpty);
    });

    test('hacen falta 10 palabras para jugar', () {
      final few = family();
      expect(few.playable, isFalse);
      expect(few.missingWords, 7);
      final enough = family(
        words: [for (var i = 0; i < CustomCategory.minWords; i++) 'P$i'],
      );
      expect(enough.playable, isTrue);
      expect(enough.missingWords, 0);
      expect(enough.wordsLabel, '10 palabras');
    });

    test('las palabras muy largas se recortan', () {
      final long = 'a' * 60;
      final result = CustomWords.add([], [long]);
      expect(result.words.single.length, CustomCategory.maxWordLength);
    });
  });

  test('por ahora no hay límite de categorías gratis', () {
    expect(CustomCategoryStore.freeLimit, isNull);
  });
}
