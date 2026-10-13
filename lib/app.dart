import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/providers.dart';
import 'router.dart';
import 'theme.dart';

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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Charadeando',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(ref.watch(backdropProvider)),
      // Los colores del juego no cambian con el modo oscuro del celular.
      themeMode: ThemeMode.light,
      routerConfig: _router,
    );
  }
}
