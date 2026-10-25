import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/providers.dart';
import 'services/crash_reporting.dart';
import 'services/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ScreenOrientation.portrait();
  // Borra videos de partidas que se cerraron a la mitad.
  VideoService().deleteAll().ignore();
  // Se leen antes de abrir la app para no mostrar la bienvenida ni por un
  // instante a quien ya la vio, ni otro fondo que el elegido.
  final welcomeSeen = await WelcomeStore().seen();
  final backdrop = await BackdropStore().load();
  final settings = await SettingsStore().load();
  // Reportes de errores (Firebase Crashlytics), según el ajuste de
  // Privacidad. Nunca en modo debug.
  await startCrashReporting(enabled: settings.shareData);
  runApp(
    ProviderScope(
      overrides: [
        welcomeSeenProvider.overrideWith(() => WelcomeSeen(welcomeSeen)),
        backdropProvider.overrideWith(() => BackdropController(backdrop)),
        settingsProvider.overrideWith(() => SettingsController(settings)),
      ],
      child: const CharadeandoApp(),
    ),
  );
}
