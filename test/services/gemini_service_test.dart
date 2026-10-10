import 'dart:convert';

import 'package:charadeando_app/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('manda el cuerpo con las instrucciones y la cantidad pedida', () async {
    late http.Request sent;
    final service = GeminiService(
      flowUrl: 'https://directus.test/flows/trigger/abc',
      client: MockClient((request) async {
        sent = request;
        return http.Response('["Peras"]', 200);
      }),
    );
    await service.fetchWords(20);

    expect(sent.method, 'POST');
    expect(sent.url.path, '/flows/trigger/abc');
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(
      body['systemInstruction']['parts'][0]['text'],
      GeminiService.instructions,
    );
    expect(body['contents'][0]['role'], 'user');
    expect(
      body['contents'][0]['parts'][0]['text'],
      'Genera exactamente 20 palabras o frases para el juego.',
    );
  });

  group('lee la lista de palabras', () {
    const words = ['Peras', 'Silla de caballo', 'Una casa embrujada'];

    test('directa', () {
      expect(GeminiService.parseWords(jsonEncode(words)), words);
    });

    test('dentro de data', () {
      expect(GeminiService.parseWords(jsonEncode({'data': words})), words);
    });

    test('en la respuesta cruda de Gemini, con markdown', () {
      final raw = {
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': '```json\n${jsonEncode(words)}\n```'},
              ],
            },
          },
        ],
      };
      expect(GeminiService.parseWords(jsonEncode(raw)), words);
      expect(GeminiService.parseWords(jsonEncode({'data': raw})), words);
    });

    test('como texto', () {
      expect(GeminiService.parseWords(jsonEncode(jsonEncode(words))), words);
      expect(GeminiService.parseWords('Aquí van: ${jsonEncode(words)}'), words);
    });

    test('sin repetidas ni vacías', () {
      expect(
        GeminiService.parseWords('["Peras", " peras ", "", "Gato  negro"]'),
        ['Peras', 'Gato negro'],
      );
    });
  });

  test('avisa si la respuesta no trae palabras', () async {
    final service = GeminiService(
      flowUrl: 'https://directus.test/flows/trigger/abc',
      client: MockClient((_) async => http.Response('{"ok":true}', 200)),
    );
    await expectLater(service.fetchWords(5), throwsA(isA<GeminiException>()));
  });
}
