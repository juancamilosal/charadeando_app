import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'providers.dart';

/// "Equipos", guardados en el celular. Se leen al empezar y se guardan en
/// cada cambio.
class TeamsController extends AsyncNotifier<List<SavedTeam>> {
  @override
  Future<List<SavedTeam>> build() => ref.read(teamStoreProvider).load();

  List<SavedTeam> get _teams => state.value ?? const [];

  Future<void> _update(List<SavedTeam> teams) async {
    state = AsyncData(teams);
    await ref.read(teamStoreProvider).save(teams);
  }

  /// Si [name] ya lo usa otro equipo (sin importar mayúsculas), distinto de
  /// [exceptId].
  bool nameTaken(String name, {String? exceptId}) {
    final key = name.trim().toLowerCase();
    return _teams.any(
      (t) => t.id != exceptId && t.name.trim().toLowerCase() == key,
    );
  }

  /// Crea el equipo si es nuevo, o lo reemplaza si ya existía.
  Future<void> save(SavedTeam team) {
    final list = [..._teams];
    final i = list.indexWhere((t) => t.id == team.id);
    if (i < 0) {
      list.add(team);
    } else {
      list[i] = team;
    }
    return _update(list);
  }

  Future<void> delete(String id) => _update([
    for (final t in _teams)
      if (t.id != id) t,
  ]);

  /// Suma al historial de los equipos guardados la partida que terminó:
  /// la partida jugada, la victoria (si ganó solo; en empate no cuenta) y
  /// el mejor puntaje si lo superó. Los equipos de una sola partida no se
  /// guardan.
  Future<void> recordGame(GameState game) async {
    final teams = await future;
    if (!game.inGroups) return;
    final scores = game.scores;
    final leaders = game.leaders;
    final winner = leaders.length == 1 ? leaders.single : null;
    final list = [...teams];
    var changed = false;
    for (var i = 0; i < game.groups.length; i++) {
      final id = game.groups[i].teamId;
      if (id == null) continue;
      final j = list.indexWhere((t) => t.id == id);
      if (j < 0) continue;
      list[j] = list[j].withGame(score: scores[i], won: i == winner);
      changed = true;
    }
    if (changed) await _update(list);
  }

  /// Id para un equipo nuevo.
  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
