import 'package:go_router/go_router.dart';

import 'screens/auto_words_screen.dart';
import 'screens/category_intro_screen.dart';
import 'screens/category_screen.dart';
import 'screens/config_screen.dart';
import 'screens/directus_test_screen.dart';
import 'screens/final_result_screen.dart';
import 'screens/free_mode_screen.dart';
import 'screens/turn_result_screen.dart';
import 'screens/turn_screen.dart';
import 'screens/video_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/word_entry_screen.dart';

abstract final class Routes {
  static const welcome = '/';
  static const categories = '/categories';
  static const categoryIntro = '/categoria';
  static const freeMode = '/libre';
  static const config = '/config';
  static const words = '/words';
  static const autoWords = '/auto-words';
  static const turn = '/turn';
  static const turnResult = '/turn-result';
  static const video = '/video';
  static const finalResult = '/final';
  static const directusTest = '/directus';
}

final router = GoRouter(
  routes: [
    GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: Routes.categories, builder: (_, _) => const CategoryScreen()),
    GoRoute(
      path: Routes.categoryIntro,
      builder: (_, _) => const CategoryIntroScreen(),
    ),
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
      path: Routes.finalResult,
      builder: (_, _) => const FinalResultScreen(),
    ),
  ],
);
