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

/// Fotomímica: los objetos y sus fotos, descargadas antes de jugar.
final photoMimeBankProvider = Provider(
  (ref) => PhotoMimeBank(ref.watch(directusServiceProvider)),
);

/// Celular juez: crea las salas en el Worker.
final judgeServiceProvider = Provider((ref) => JudgeService());

/// La sala del celular juez de la partida, o nada si no se usa.
final judgeProvider = NotifierProvider<JudgeController, JudgeSetup>(
  JudgeController.new,
);

/// Si puede usar el celular juez (es de pago; ver
/// [PremiumAccess.canUseJudge]).
final judgeUnlockedProvider = Provider(
  (ref) => ref.watch(premiumProvider).canUseJudge(ref.watch(clockProvider)()),
);

final tiltServiceProvider = Provider((ref) => TiltService());
final tvServiceProvider = Provider((ref) => TvService());
final punishmentStoreProvider = Provider((ref) => PunishmentStore());

/// Los castigos que pone la app: los de Directus o los de respaldo.
final punishmentPoolProvider = Provider((ref) => defaultPunishmentPool());
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
  (ref) => defaultPremiumBilling([for (final c in GameCategory.paid) c.code]),
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
  final owned = ref.watch(premiumProvider).categories;
  return {
    for (final c in ref.watch(premiumCategoriesProvider))
      if (!owned.contains(c.code)) c,
  };
});

final gameControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);

final turnVideoProvider = NotifierProvider<TurnVideoController, TurnVideoState>(
  TurnVideoController.new,
);

/// Cómo está el celular juez: apagado, creando la sala, con un error o con
/// la sala lista.
class JudgeSetup {
  const JudgeSetup({this.room, this.creating = false, this.error});

  final JudgeRoom? room;
  final bool creating;
  final String? error;

  /// Encendido: con la sala o creándola.
  bool get on => room != null || creating;
}

class JudgeController extends Notifier<JudgeSetup> {
  /// La sala abierta, para cerrarla al final (al cerrar no se puede leer
  /// el estado).
  JudgeRoom? _open;

  @override
  set state(JudgeSetup value) {
    super.state = value;
    _open = value.room;
  }

  @override
  JudgeSetup get state => super.state;

  @override
  JudgeSetup build() {
    ref.onDispose(() => _open?.close());
    return const JudgeSetup();
  }

  /// La sala, si está lista y sigue existiendo.
  JudgeRoom? get room {
    final room = state.room;
    return room == null || room.gone.value ? null : room;
  }

  /// Crea la sala (si no hay una que sirva) y se conecta.
  Future<void> start() async {
    if (state.creating || room != null) return;
    await state.room?.close();
    state = const JudgeSetup(creating: true);
    try {
      final created = await ref.read(judgeServiceProvider).create();
      if (!ref.mounted) {
        await created.close();
        return;
      }
      state = JudgeSetup(room: created);
    } on JudgeException catch (e) {
      if (ref.mounted) state = JudgeSetup(error: e.message);
    }
  }

  /// Apaga el celular juez y cierra la sala.
  Future<void> stop() async {
    final old = state.room;
    state = const JudgeSetup();
    await old?.close();
  }
}
