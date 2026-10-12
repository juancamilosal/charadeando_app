import '../models/models.dart';
import 'config_store.dart';

/// "Partida rápida": se salta la configuración.
abstract final class QuickGame {
  /// La partida rápida de [base] (su categoría, mezcla y de dónde salen las
  /// palabras): sin grupos, un solo turno de un minuto, dificultad
  /// Mezcladas y aciertos con movimiento, o con los botones del juez si hay
  /// un TV conectado. El video usa la resolución de la última configuración
  /// guardada ([saved]); si era "sin video", tampoco se graba.
  static GameConfig config(
    GameConfig base, {
    SavedConfig? saved,
    bool tv = false,
  }) {
    final config = base.copyWith(
      quick: true,
      inGroups: false,
      groups: const [Group('')],
      rounds: 1,
      turnDuration: GameConfig.quickTurn,
      scoringMode: ScoringMode.perPhrase,
      hitMode: tv ? HitMode.tv : HitMode.tilt,
      resolution: saved?.resolution ?? const GameConfig().resolution,
    );
    return config.usesDifficulty
        ? config.copyWith(difficulty: Difficulty.mixed)
        : config.copyWith(clearDifficulty: true);
  }

  /// La partida personalizada que sigue a una rápida: la misma categoría,
  /// con la configuración de siempre. Si [quick] no es una partida rápida,
  /// queda igual.
  static GameConfig custom(GameConfig quick) {
    const defaults = GameConfig();
    if (!quick.quick) return quick;
    return quick.copyWith(
      quick: false,
      groups: defaults.groups,
      rounds: defaults.rounds,
      turnDuration: defaults.turnDuration,
      hitMode: HitMode.tilt,
    );
  }
}
