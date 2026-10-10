import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/services.dart';
import 'game_controller.dart';
import 'turn_video_controller.dart';

export 'game_controller.dart';
export 'turn_video_controller.dart';

final wordServiceProvider = Provider((ref) => WordService());
final directusServiceProvider = Provider((ref) => DirectusService());
final geminiServiceProvider = Provider((ref) => GeminiService());
final wordBankProvider = Provider(
  (ref) => WordBank(
    ref.watch(geminiServiceProvider),
    ref.watch(directusServiceProvider),
  ),
);
final tiltServiceProvider = Provider((ref) => TiltService());
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
