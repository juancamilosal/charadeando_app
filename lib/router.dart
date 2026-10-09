import 'package:go_router/go_router.dart';

import 'screens/config_screen.dart';
import 'screens/final_result_screen.dart';
import 'screens/turn_result_screen.dart';
import 'screens/turn_screen.dart';
import 'screens/video_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/word_entry_screen.dart';

abstract final class Routes {
  static const welcome = '/';
  static const config = '/config';
  static const words = '/words';
  static const turn = '/turn';
  static const turnResult = '/turn-result';
  static const video = '/video';
  static const finalResult = '/final';
}

final router = GoRouter(
  routes: [
    GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: Routes.config, builder: (_, _) => const ConfigScreen()),
    GoRoute(path: Routes.words, builder: (_, _) => const WordEntryScreen()),
    GoRoute(path: Routes.turn, builder: (_, _) => const TurnScreen()),
    GoRoute(
      path: Routes.turnResult,
      builder: (_, _) => const TurnResultScreen(),
    ),
    GoRoute(path: Routes.video, builder: (_, _) => const VideoScreen()),
    GoRoute(
      path: Routes.finalResult,
      builder: (_, _) => const FinalResultScreen(),
    ),
  ],
);
