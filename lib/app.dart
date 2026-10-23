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

  final _messenger = GlobalKey<ScaffoldMessengerState>();

  /// Ya se ofreció "Reiniciar" con la versión nueva en esta sesión.
  bool _updateOffered = false;
  late final AppUpdateController _updates = ref.read(appUpdateProvider);

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
    // Estadísticas anónimas: se envían las que quedaron pendientes y se
    // dejan de enviar (y se borran) si apagan el ajuste de Privacidad.
    final stats = ref.read(statsServiceProvider)
      ..enabled = ref.read(settingsProvider).shareData;
    stats.flush().ignore();
    ref.listenManual(settingsProvider.select((s) => s.shareData), (_, on) {
      stats.enabled = on;
      if (!on) stats.clear().ignore();
      ErrorReporter.instance.setEnabled(on).ignore();
    });
    // La pantalla actual acompaña cada reporte de error.
    _router.routerDelegate.addListener(_reportScreen);
    // Actualizaciones de Google Play: se busca al abrir y, si hay una, se
    // baja mientras se juega; cuando está lista se ofrece "Reiniciar".
    _updates.ready.addListener(_offerUpdate);
    _router.routerDelegate.addListener(_offerUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  String get _path => _router.routerDelegate.currentConfiguration.uri.path;

  /// En el turno o viendo un video no se interrumpe con avisos.
  bool get _busy => _path == Routes.turn || _path == Routes.video;

  void _checkUpdate() {
    if (_busy) return;
    _updates.check().ignore();
  }

  /// La versión nueva ya se bajó: se ofrece reiniciar, una vez, fuera del
  /// turno.
  void _offerUpdate() {
    if (_updateOffered || !_updates.ready.value || _busy) return;
    _updateOffered = true;
    _messenger.currentState?.showSnackBar(
      SnackBar(
        content: const Text('Hay una versión nueva de Charadeando lista.'),
        duration: const Duration(seconds: 15),
        action: SnackBarAction(
          label: 'Reiniciar',
          onPressed: () => _updates.install().ignore(),
        ),
      ),
    );
  }

  void _reportScreen() {
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    ErrorReporter.instance.setKey(CrashKeys.screen, path);
  }

  /// En segundo plano (o con el celular bloqueado) la música se pausa.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(backgroundMusicProvider).foreground =
        state == AppLifecycleState.resumed;
    // Al volver a la app se busca de nuevo (como mucho una vez por hora).
    if (state == AppLifecycleState.resumed) _checkUpdate();
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
    _router.routerDelegate.removeListener(_reportScreen);
    _router.routerDelegate.removeListener(_offerUpdate);
    _updates.ready.removeListener(_offerUpdate);
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
      scaffoldMessengerKey: _messenger,
    );
  }
}
