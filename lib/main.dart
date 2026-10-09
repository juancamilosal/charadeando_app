import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ScreenOrientation.portrait();
  // Borra videos de partidas que se cerraron a la mitad.
  VideoService().deleteAll().ignore();
  runApp(const ProviderScope(child: CharadeandoApp()));
}
