import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'custom_categories_controller.dart';
import 'my_videos_controller.dart';
import 'teams_controller.dart';
import 'game_controller.dart';
import 'turn_video_controller.dart';

export 'custom_categories_controller.dart';
export 'my_videos_controller.dart';
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

/// Música y efectos de sonido, según los ajustes.
final soundServiceProvider = Provider((ref) {
  final settings = ref.watch(settingsProvider);
  return SoundService(music: settings.music, effects: settings.sounds);
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

/// Si el usuario compró las funciones premium. Las compras llegan en una
/// versión posterior.
///
/// TEMPORAL: en true para probar las funciones premium. Volver a false
/// antes de publicar.
final premiumUnlockedProvider = Provider((ref) => true);

/// La fecha de hoy. Las pruebas la cambian para ver las categorías de
/// temporada (como Navidad) dentro y fuera de sus fechas.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Categorías del juego que se desbloquean con premium.
final premiumCategoriesProvider = Provider<Set<GameCategory>>(
  (ref) => {
    for (final c in GameCategory.values)
      if (c.premium) c,
  },
);

final gameControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);

final turnVideoProvider = NotifierProvider<TurnVideoController, TurnVideoState>(
  TurnVideoController.new,
);
