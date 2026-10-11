import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/services.dart';
import 'custom_categories_controller.dart';
import 'my_videos_controller.dart';
import 'game_controller.dart';
import 'turn_video_controller.dart';

export 'custom_categories_controller.dart';
export 'my_videos_controller.dart';
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

final gameControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);

final turnVideoProvider = NotifierProvider<TurnVideoController, TurnVideoState>(
  TurnVideoController.new,
);
