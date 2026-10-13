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
import 'screens/settings_screen.dart';
import 'screens/team_editor_screen.dart';
import 'screens/teams_screen.dart';
import 'screens/turn_result_screen.dart';
import 'screens/turn_screen.dart';
import 'screens/video_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/word_entry_screen.dart';
import 'widgets/app_nav_bar.dart';
import 'widgets/music_silence.dart';
import 'widgets/punishment_roulette.dart';

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

  /// "Equipos" y crear o editar uno (recibe el equipo como `extra` para
  /// editarlo y vuelve con el equipo guardado).
  static const teams = '/equipos';
  static const teamEditor = '/equipo';

  /// "Ajustes".
  static const settings = '/ajustes';

  /// "Mis videos" y ver uno de ellos, que recibe el video como `extra`.
  static const myVideos = '/mis-videos';
  static const myVideo = '/mis-videos/ver';

  /// La ruleta a pantalla completa: al final de la partida (recibe el
  /// nombre del equipo como `extra`) o desde la sección Ruleta (recibe la
  /// lista de castigos).
  static const punishmentSpin = '/castigo';
}

/// Las rutas de la app. La primera vez abre en la bienvenida y no deja ir
/// a otra pantalla hasta tocar "Listo"; después, abre directo en Categorías.
///
/// Ruleta, Equipos, Categorías, Videos y Ajustes son las pestañas de la
/// barra de abajo: cada una conserva su estado. Las demás pantallas (la
/// configuración, las palabras, el turno, los resultados, el video, la
/// bienvenida…) se abren encima, sin la barra.
GoRouter createRouter({required bool Function() welcomeSeen}) => GoRouter(
  initialLocation: welcomeSeen() ? Routes.categories : Routes.welcome,
  redirect: (_, state) =>
      !welcomeSeen() && state.matchedLocation != Routes.welcome
      ? Routes.welcome
      : null,
  routes: appRoutes,
);

/// Todas las rutas, también para las pruebas.
final List<RouteBase> appRoutes = [
  StatefulShellRoute.indexedStack(
    builder: (context, state, shell) => AppNavShell(shell: shell),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.punishments,
            builder: (_, _) => const RouletteScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(path: Routes.teams, builder: (_, _) => const TeamsScreen()),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.categories,
            builder: (_, _) => const CategoryScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.myVideos,
            builder: (_, _) => const MyVideosScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.settings,
            builder: (_, _) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  ),
  GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
  GoRoute(path: Routes.freeMode, builder: (_, _) => const FreeModeScreen()),
  GoRoute(path: Routes.config, builder: (_, _) => const ConfigScreen()),
  GoRoute(path: Routes.words, builder: (_, _) => const WordEntryScreen()),
  GoRoute(path: Routes.autoWords, builder: (_, _) => const AutoWordsScreen()),
  // El turno y los videos tienen su propio sonido: sin música de fondo.
  GoRoute(
    path: Routes.turn,
    builder: (_, _) => const MusicSilence(child: TurnScreen()),
  ),
  GoRoute(path: Routes.turnResult, builder: (_, _) => const TurnResultScreen()),
  GoRoute(
    path: Routes.video,
    builder: (_, _) => const MusicSilence(child: VideoScreen()),
  ),
  GoRoute(
    path: Routes.directusTest,
    builder: (_, _) => const DirectusTestScreen(),
  ),
  GoRoute(
    path: Routes.customCategory,
    builder: (_, state) =>
        CustomCategoryScreen(category: state.extra as CustomCategory?),
  ),
  GoRoute(
    path: Routes.teamEditor,
    builder: (_, state) => TeamEditorScreen(team: state.extra as SavedTeam?),
  ),
  GoRoute(path: Routes.backdrops, builder: (_, _) => const BackdropScreen()),
  GoRoute(
    path: Routes.myVideo,
    builder: (_, state) =>
        MusicSilence(child: MyVideoScreen(video: state.extra! as SavedVideo)),
  ),
  GoRoute(
    path: Routes.punishmentSpin,
    // Al final de la partida recibe el nombre del equipo; desde la sección
    // Ruleta, los castigos con que se gira y cómo arrancó el giro.
    builder: (_, state) => switch (state.extra) {
      (final List<String> punishments, final RouletteSpin spin) =>
        PunishmentSpinScreen(punishments: punishments, startWith: spin),
      final List<String> punishments => PunishmentSpinScreen(
        punishments: punishments,
      ),
      final String group => PunishmentSpinScreen(groupName: group),
      _ => const PunishmentSpinScreen(),
    },
  ),
  GoRoute(
    path: Routes.finalResult,
    builder: (_, _) => const FinalResultScreen(),
  ),
];
