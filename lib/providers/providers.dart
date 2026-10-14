import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'custom_categories_controller.dart';
import 'my_videos_controller.dart';
import 'premium_controller.dart';
import 'teams_controller.dart';
import 'game_controller.dart';
import 'turn_video_controller.dart';

export 'custom_categories_controller.dart';
export 'my_videos_controller.dart';
export 'premium_controller.dart';
export 'teams_controller.dart';
export 'game_controller.dart';
export 'turn_video_controller.dart';

final wordServiceProvider = Provider((ref) => WordService());
final directusServiceProvider = Provider((ref) => DirectusService());
final wordBankProvider = Provider(
  (ref) => WordBank(ref.watch(directusServiceProvider)),
);
final tiltServiceProvider = Provider((ref) => TiltService());
final tvServiceProvider = Provider((ref) => TvService());
final punishmentStoreProvider = Provider((ref) => PunishmentStore());
final configStoreProvider = Provider((ref) => ConfigStore());
final customCategoryStoreProvider = Provider((ref) => CustomCategoryStore());
final welcomeStoreProvider = Provider((ref) => WelcomeStore());
final backdropStoreProvider = Provider((ref) => BackdropStore());
final mixStoreProvider = Provider((ref) => MixStore());

/// El fondo de la app. `main` lo lee del celular antes de abrir la app,
/// para que se vea el elegido desde la primera pantalla.
final backdropProvider = NotifierProvider<BackdropController, Backdrop>(
  BackdropController.new,
);

class BackdropController extends Notifier<Backdrop> {
  BackdropController([this._initial = Backdrop.standard]);

  final Backdrop _initial;

  @override
  Backdrop build() => _initial;

  /// Cambia el fondo de toda la app y lo guarda en el celular.
  void select(Backdrop backdrop) {
    if (backdrop == state) return;
    state = backdrop;
    ref.read(backdropStoreProvider).save(backdrop).ignore();
  }
}

final settingsStoreProvider = Provider((ref) => SettingsStore());

/// Los ajustes de la app. `main` los lee del celular antes de abrir la app.
final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  SettingsController([this._initial = const AppSettings()]);

  final AppSettings _initial;

  @override
  AppSettings build() {
    ScreenOrientation.inverted = _initial.invertedRotation;
    return _initial;
  }

  /// Cambia los ajustes y los guarda en el celular.
  void update(AppSettings settings) {
    state = settings;
    ScreenOrientation.inverted = settings.invertedRotation;
    ref.read(settingsStoreProvider).save(settings).ignore();
  }
}

/// Vibraciones, según el ajuste "Vibración".
final hapticsProvider = Provider(
  (ref) => Haptics(enabled: ref.watch(settingsProvider).vibration),
);

/// El reproductor de los efectos de sonido; las pruebas lo cambian.
final effectPlayerProvider = Provider<EffectPlayer>(
  (ref) => defaultEffectPlayer(),
);

/// Efectos de sonido, según el ajuste "Efectos de sonido".
final soundServiceProvider = Provider(
  (ref) => SoundService(
    effects: ref.watch(settingsProvider).sounds,
    player: ref.watch(effectPlayerProvider),
  ),
);

/// El reproductor de la música de fondo; las pruebas lo cambian.
final musicPlayerProvider = Provider<MusicPlayer>(
  (ref) => defaultMusicPlayer(),
);

/// La música de fondo. La app la enciende o apaga según el ajuste "Música"
/// y la pausa en segundo plano; el turno y los videos la silencian.
final backgroundMusicProvider = Provider((ref) {
  final music = BackgroundMusic(ref.watch(musicPlayerProvider));
  ref.onDispose(music.dispose);
  return music;
});

final teamStoreProvider = Provider((ref) => TeamStore());

/// "Equipos", guardados en el celular.
final teamsProvider = AsyncNotifierProvider<TeamsController, List<SavedTeam>>(
  TeamsController.new,
);

final videoGalleryProvider = Provider((ref) => VideoGallery());
final myVideosStoreProvider = Provider((ref) => MyVideosStore());

/// "Mis videos": los videos guardados en la galería desde la app.
final myVideosProvider =
    AsyncNotifierProvider<MyVideosController, MyVideosData>(
      MyVideosController.new,
    );

/// Si ya se vio la bienvenida. `main` lo lee del celular antes de abrir la
/// app, para que la primera pantalla sea la correcta desde el principio.
final welcomeSeenProvider = NotifierProvider<WelcomeSeen, bool>(
  WelcomeSeen.new,
);

class WelcomeSeen extends Notifier<bool> {
  WelcomeSeen([this._initial = false]);

  final bool _initial;

  @override
  bool build() => _initial;

  /// Se tocó "Listo": las próximas veces la app abre en Categorías.
  void markSeen() {
    if (state) return;
    state = true;
    ref.read(welcomeStoreProvider).markSeen().ignore();
  }
}

/// "Mis categorías", guardadas en el celular.
final customCategoriesProvider =
    AsyncNotifierProvider<CustomCategoriesController, CustomCategoriesData>(
      CustomCategoriesController.new,
    );

/// Si hay un televisor conectado al celular, para el Modo TV.
final tvConnectedProvider = StreamProvider<bool>(
  (ref) => ref.watch(tvServiceProvider).connection(),
);
final videoServiceProvider = Provider((ref) => VideoService());
final videoRendererProvider = Provider((ref) => VideoRenderer());

final premiumStoreProvider = Provider((ref) => PremiumStore());
final premiumBillingProvider = Provider<PremiumBilling>(
  (ref) => defaultPremiumBilling(),
);
final promoCodeServiceProvider = Provider((ref) => PromoCodeService());

/// Lo desbloqueado, con la compra de Google Play y los códigos.
final premiumProvider = NotifierProvider<PremiumController, PremiumAccess>(
  PremiumController.new,
);

/// Si tiene Premium (comprado o con un código que abre todo): todas las
/// categorías, video Full HD y Máxima y categorías propias sin límite.
final premiumUnlockedProvider = Provider(
  (ref) => ref.watch(premiumProvider).premium,
);

/// La fecha de hoy. Las pruebas la cambian para ver las categorías de
/// temporada (como Navidad) dentro y fuera de sus fechas.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Muestra las categorías especiales (como Navidad) todo el año, fuera de
/// sus fechas.
///
/// TEMPORAL: en true para probar Navidad. Volver a false antes de
/// publicar.
final allSeasonsProvider = Provider((ref) => true);

/// Categorías del juego que se desbloquean con premium.
final premiumCategoriesProvider = Provider<Set<GameCategory>>(
  (ref) => GameCategory.paid,
);

/// Categorías de pago que este usuario todavía no puede jugar: llevan
/// candado.
final lockedCategoriesProvider = Provider<Set<GameCategory>>((ref) {
  if (ref.watch(premiumUnlockedProvider)) return const {};
  final byCode = ref.watch(premiumProvider).codeCategories;
  return {
    for (final c in ref.watch(premiumCategoriesProvider))
      if (!byCode.contains(c.code)) c,
  };
});

final gameControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);

final turnVideoProvider = NotifierProvider<TurnVideoController, TurnVideoState>(
  TurnVideoController.new,
);
