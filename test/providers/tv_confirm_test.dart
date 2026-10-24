import 'package:charadeando_app/providers/providers.dart';
import 'package:charadeando_app/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un celular que avisó que había TV y nunca avisó que se desconectó: el
/// aviso dice "conectado", pero el sistema, si se le pregunta, dice que no.
class _StaleTv extends TvService {
  bool connectedNow = false;
  int listens = 0;

  @override
  Stream<bool> connection() async* {
    listens++;
    yield listens == 1 ? true : connectedNow;
  }

  @override
  Future<bool?> isConnected() async => connectedNow;
}

void main() {
  testWidgets('si el aviso del TV quedó viejo, se corrige al preguntar', (
    tester,
  ) async {
    final tv = _StaleTv();
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tvServiceProvider.overrideWithValue(tv)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              final on = ref.watch(tvConnectedProvider).value ?? false;
              return Text(on ? 'TV' : 'Sin TV');
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('TV'), findsOneWidget);

    expect(await confirmTvConnected(widgetRef), isFalse);
    await tester.pump();
    await tester.pump();
    expect(find.text('Sin TV'), findsOneWidget);
    expect(tv.listens, 2);
  });
}
