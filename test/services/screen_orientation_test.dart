import 'package:charadeando_app/services/screen_orientation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('charadeando/pantalla');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<Object?> preferred;
  String? side;

  setUp(() {
    ScreenOrientation.native = true;
    preferred = [];
    side = 'izquierda';
    ScreenOrientation.game = DeviceOrientation.landscapeLeft;
    messenger.setMockMethodCallHandler(channel, (call) async => side);
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        preferred.add(call.arguments);
      }
      return null;
    });
  });

  tearDown(() {
    ScreenOrientation.native = false;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> giro(String lado) => messenger.handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(MethodCall('giro', lado)),
    (_) {},
  );

  test('antes de la cuenta la pantalla sigue al lado del celular', () async {
    await ScreenOrientation.landscape();
    // Android gira solo: Flutter no fija ningún lado.
    expect(preferred, isEmpty);

    final changes = <DeviceOrientation>[];
    final sub = ScreenOrientation.changes.listen(changes.add);
    addTearDown(sub.cancel);
    await giro('derecha');
    await giro('derecha');
    await pumpEventQueue();
    expect(ScreenOrientation.game, DeviceOrientation.landscapeRight);
    expect(changes, [DeviceOrientation.landscapeRight]);
  });

  test('en la cuenta se fija en el lado en que está', () async {
    side = 'derecha';
    await ScreenOrientation.lock();
    expect(ScreenOrientation.game, DeviceOrientation.landscapeRight);
    expect(preferred.last, ['DeviceOrientation.landscapeRight']);
  });

  test('si la pantalla sigue vertical, se queda el último lado', () async {
    ScreenOrientation.game = DeviceOrientation.landscapeRight;
    side = null;
    await ScreenOrientation.lock();
    expect(preferred.last, ['DeviceOrientation.landscapeRight']);
  });

  test('sin Android, Flutter deja girar a los dos lados', () async {
    ScreenOrientation.native = false;
    await ScreenOrientation.landscape();
    expect(preferred.last, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
  });
}
