import 'dart:math';

import 'package:charadeando_app/services/test_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada grupo recibe sus propias palabras de prueba', () {
    final words = TestData.words(random: Random(3));
    expect(words, hasLength(TestData.config.groupCount));
    for (final group in words) {
      expect(group, hasLength(TestData.config.wordsPerGroup));
    }
    final all = words.expand((w) => w).toList();
    expect(all.toSet(), hasLength(all.length));
  });
}
