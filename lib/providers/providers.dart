import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/services.dart';
import 'game_controller.dart';

export 'game_controller.dart';

final wordServiceProvider = Provider((ref) => WordService());
final tiltServiceProvider = Provider((ref) => TiltService());
final videoServiceProvider = Provider((ref) => VideoService());

/// Si el usuario compró las funciones premium. Las compras llegan en una
/// versión posterior; por ahora siempre es falso.
final premiumUnlockedProvider = Provider((ref) => false);

final gameControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);
