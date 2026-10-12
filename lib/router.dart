import 'package:go_router/go_router.dart';

import 'models/models.dart';
import 'screens/auto_words_screen.dart';
import 'screens/backdrop_screen.dart';
import 'screens/category_screen.dart';
import 'screens/config_screen.dart';
import 'screens/custom_category_screen.dart';
import 'screens/directus_test_screen.dart';
import 'screens/final_result_screen.dart';
import 'screens/free_mode_screen.dart';
import 'screens/my_videos_screen.dart';
import 'screens/roulette_screen.dart';
import 'screens/turn_result_screen.dart';
import 'screens/turn_screen.dart';
import 'screens/video_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/word_entry_screen.dart';

abstract final class Routes {
  /// Solo se ve la primera vez que se abre la app, o con el botón "i" de
  /// Categorías.
  static const welcome = '/bienvenida';
  static const categories = '/';
  static const freeMode = '/libre';
  static const config = '/config';
  static const words = '/words';
  static const autoWords = '/auto-words';
  static const turn = '/turn';
  static const turnResult = '/turn-result';
  static const video = '/video';
  static const finalResult = '/final';
  static const directusTest = '/directus';

  /// Sección "Ruleta de castigos".
  static const punishments = '/ruleta';

  /// Crear o editar una categoría propia. Para editar recibe la categoría
  /// como `extra`.
  static const customCategory = '/mis-categorias';

  /// Elegir el fondo de la app.
  static const backdrops = '/fondos';

  /// "Mis videos" y ver uno de ellos, que recibe el video como `extra`.
  static const myVideos = '/mis-videos';
  static const myVideo = '/mis-videos/ver';

  /// Ruleta de castigo de un grupo al final de la partida. Recibe el nombre
  /// del grupo como `extra`.
  static const punishmentSpin = '/castigo';
}

/// Las rutas de la app. La primera vez abre en la bienvenida y no deja ir
/// a otra pantalla hasta tocar "Listo"; después, abre directo en Categorías.
GoRouter createRouter({required bool Function() welcomeSeen}) => GoRouter(
  initialLocation: welcomeSeen() ? Routes.categories : Routes.welcome,
  redirect: (_, state) =>
      !welcomeSeen() && state.matchedLocation != Routes.welcome
      ? Routes.welcome
      : null,
  routes: [
    GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: Routes.categories, builder: (_, _) => const CategoryScreen()),
    GoRoute(path: Routes.freeMode, builder: (_, _) => const FreeModeScreen()),
    GoRoute(path: Routes.config, builder: (_, _) => const ConfigScreen()),
    GoRoute(path: Routes.words, builder: (_, _) => const WordEntryScreen()),
    GoRoute(path: Routes.autoWords, builder: (_, _) => const AutoWordsScreen()),
    GoRoute(path: Routes.turn, builder: (_, _) => const TurnScreen()),
    GoRoute(
      path: Routes.turnResult,
      builder: (_, _) => const TurnResultScreen(),
    ),
    GoRoute(path: Routes.video, builder: (_, _) => const VideoScreen()),
    GoRoute(
      path: Routes.directusTest,
      builder: (_, _) => const DirectusTestScreen(),
    ),
    GoRoute(
      path: Routes.punishments,
      builder: (_, _) => const RouletteScreen(),
    ),
    GoRoute(
      path: Routes.customCategory,
      builder: (_, state) =>
          CustomCategoryScreen(category: state.extra as CustomCategory?),
    ),
    GoRoute(path: Routes.backdrops, builder: (_, _) => const BackdropScreen()),
    GoRoute(path: Routes.myVideos, builder: (_, _) => const MyVideosScreen()),
    GoRoute(
      path: Routes.myVideo,
      builder: (_, state) => MyVideoScreen(video: state.extra! as SavedVideo),
    ),
    GoRoute(
      path: Routes.punishmentSpin,
      builder: (_, state) =>
          PunishmentSpinScreen(groupName: state.extra as String? ?? ''),
    ),
    GoRoute(
      path: Routes.finalResult,
      builder: (_, _) => const FinalResultScreen(),
    ),
  ],
);
