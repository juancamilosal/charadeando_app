import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/providers.dart';
import 'services/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ScreenOrientation.portrait();
  // Borra videos de partidas que se cerraron a la mitad.
  VideoService().deleteAll().ignore();
  // Se lee antes de abrir la app para no mostrar la bienvenida ni por un
  // instante a quien ya la vio.
  final welcomeSeen = await WelcomeStore().seen();
  runApp(
    ProviderScope(
      overrides: [
        welcomeSeenProvider.overrideWith(() => WelcomeSeen(welcomeSeen)),
      ],
      child: const CharadeandoApp(),
    ),
  );
}
