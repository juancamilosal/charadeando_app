import 'package:charadeando_app/models/models.dart';
import 'package:charadeando_app/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/config_screen_test.dart' show MemoryTeamStore;

void main() {
  /// Juega una partida de dos equipos guardados con [category]: Los Primos
  /// aciertan [primos] palabras y Las Tías, [tias].
  Future<void> play(
    ProviderContainer c,
    GameCategory category, {
    required int primos,
    required int tias,
  }) async {
    final game = c.read(gameControllerProvider.notifier);
    game.configure(
      GameConfig(
        category: category,
        rounds: 1,
        groups: const [
          Group('Los Primos', teamId: 'p'),
          Group('Las Tías', teamId: 't'),
        ],
      ),
    );
    game.startWithDecks([
      [for (var i = 0; i < 10; i++) Word('P$i')],
      [for (var i = 0; i < 10; i++) Word('T$i')],
    ]);
    for (final (group, hits) in [(0, primos), (1, tias)]) {
      game.finishTurn(
        Turn(
          round: 1,
          groupIndex: group,
          entries: [
            for (var i = 0; i < hits; i++)
              TurnEntry(Word('$group-$i'), WordOutcome.hit),
          ],
        ),
      );
      game.advance();
    }
    await game.saveHistory();
  }

  test('el puntaje acumulado sigue de una categoría a otra y se reinicia '
      'sin tocar el historial', () async {
    final store = MemoryTeamStore(const [
      SavedTeam(id: 'p', name: 'Los Primos'),
      SavedTeam(id: 't', name: 'Las Tías'),
    ]);
    final c = ProviderContainer(
      overrides: [teamStoreProvider.overrideWithValue(store)],
    );
    addTearDown(c.dispose);
    await c.read(teamsProvider.future);

    await play(c, GameCategory.animals, primos: 7, tias: 5);
    await play(c, GameCategory.movies, primos: 2, tias: 6);
    var teams = await c.read(teamsProvider.future);
    expect([for (final t in teams) t.total], [9, 11]);
    expect([for (final t in teams) t.played], [2, 2]);
    expect([for (final t in teams) t.wins], [1, 1]);
    // Se guarda en el celular.
    expect(SavedTeam.fromJson(store.teams.first.toJson()).total, 9);

    await c.read(teamsProvider.notifier).resetTotals();
    teams = await c.read(teamsProvider.future);
    expect([for (final t in teams) t.total], [0, 0]);
    expect([for (final t in teams) t.played], [2, 2]);
  });
}
