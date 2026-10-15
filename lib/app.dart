import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/models.dart';
import 'providers/providers.dart';
import 'services/services.dart';
import 'router.dart';
import 'theme.dart';
import 'widgets/tap_sounds.dart';

class CharadeandoApp extends ConsumerStatefulWidget {
  const CharadeandoApp({super.key});

  @override
  ConsumerState<CharadeandoApp> createState() => _CharadeandoAppState();
}

class _CharadeandoAppState extends ConsumerState<CharadeandoApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = createRouter(
    welcomeSeen: () => ref.read(welcomeSeenProvider),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Los castigos de Directus se traen al abrir, para tenerlos listos en
    // la ruleta.
    ref.read(punishmentPoolProvider).load().ignore();
    // La música de fondo suena según el ajuste "Música" y se apaga en
    // cuanto lo desactivan.
    ref.read(backgroundMusicProvider).enabled = ref
        .read(settingsProvider)
        .music;
    ref.listenManual(
      settingsProvider.select((s) => s.music),
      (_, on) => ref.read(backgroundMusicProvider).enabled = on,
    );
  }

  /// En segundo plano (o con el celular bloqueado) la música se pausa.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(backgroundMusicProvider).foreground =
        state == AppLifecycleState.resumed;
  }

  /// El sonido de un toque, si "Efectos de sonido" está encendido y no se
  /// está en el turno ni viendo un video.
  void _tapSound() {
    if (ref.read(backgroundMusicProvider).silenced) return;
    ref.read(soundServiceProvider).play(SoundEffect.tap);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  /// El fondo elegido; uno exclusivo (Oro) solo con Todo Charadeando.
  Backdrop _backdrop() {
    return ref
        .watch(backdropProvider)
        .allowedWith(premium: ref.watch(premiumUnlockedProvider));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Charadeando',
      debugShowCheckedModeBanner: false,
      // El toque de los botones suena en toda la app.
      theme: buildAppTheme(_backdrop())
          .copyWith(splashFactory: TapSoundSplashFactory(onTap: _tapSound)),
      // Los colores del juego no cambian con el modo oscuro del celular.
      themeMode: ThemeMode.light,
      routerConfig: _router,
    );
  }
}
