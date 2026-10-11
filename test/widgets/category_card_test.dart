import 'package:charadeando_app/widgets/category_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // En las pruebas cada letra mide lo mismo que el tamaño de la fuente.
  const style = TextStyle(fontFamily: 'FlutterTest');

  testWidgets('una palabra larga se achica en vez de partirse', (tester) async {
    final size = CategoryCard.fitTitleSize(
      'Celebridades',
      style,
      width: 120,
      maxSize: 30,
      minSize: 5,
    );
    // 12 letras deben caber en 120 de ancho.
    expect(size * 12, lessThanOrEqualTo(120));
    expect(size, greaterThan(9));
  });

  testWidgets('varias palabras usan dos renglones sin partir ninguna', (
    tester,
  ) async {
    final size = CategoryCard.fitTitleSize(
      'Mi familia',
      style,
      width: 120,
      maxSize: 30,
      minSize: 5,
    );
    // "familia" (7 letras) cabe entera en un renglón.
    expect(size * 7, lessThanOrEqualTo(120));
    expect(size, greaterThan(15));
  });

  testWidgets('si ni con la letra más pequeña cabe, usa la mínima', (
    tester,
  ) async {
    final size = CategoryCard.fitTitleSize(
      'Supercalifragilisticoespialidoso',
      style,
      width: 60,
      maxSize: 30,
      minSize: 5,
    );
    expect(size, 5);
  });
}
