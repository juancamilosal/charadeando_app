import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Claves de los archivos JSON que se guardan en el celular: no las ve el
/// usuario y cambiarlas borraría lo guardado.
const _jsonKeys = {'grupo', 'grupos', 'palabrasPorGrupo'};

void main() {
  test('ningún texto de la app dice "grupo": ahora son equipos', () {
    final literal = RegExp(r"'([^'\\]|\\.)*'");
    final found = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('//')) continue;
        for (final m in literal.allMatches(line)) {
          final text = m.group(0)!;
          final inner = text.substring(1, text.length - 1);
          if (_jsonKeys.contains(inner)) continue;
          if (inner.toLowerCase().contains('grupo')) {
            found.add('${file.path}:${i + 1}: $text');
          }
        }
      }
    }
    expect(found, isEmpty);
  });
}
