import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets/play_background.dart';
import '../widgets/team_badge.dart';

/// "Equipos": los equipos guardados en el celular, con su historial.
/// Mantener presionado uno (o su botón de tres puntos) deja editarlo o
/// borrarlo.
class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});

  Future<void> _options(
    BuildContext context,
    WidgetRef ref,
    SavedTeam team,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.purple),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(context, 'editar'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.coral),
              title: const Text('Borrar'),
              onTap: () => Navigator.pop(context, 'borrar'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'editar') {
      context.push(Routes.teamEditor, extra: team);
    } else if (choice == 'borrar') {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('¿Borrar "${team.name}"?'),
          content: const Text('Se borrará también su historial.'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.purple),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Borrar'),
            ),
          ],
        ),
      );
      if (sure == true) {
        await ref.read(teamsProvider.notifier).delete(team.id);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = ref.watch(teamsProvider).value;
    final on = context.onBackdrop;
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Equipos')),
        body: SafeArea(
          top: false,
          child: teams == null
              ? Center(child: CircularProgressIndicator(color: on))
              : teams.isEmpty
              ? _Empty(onCreate: () => context.push(Routes.teamEditor))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        children: [
                          for (final team in teams) ...[
                            _TeamCard(
                              team: team,
                              onOptions: () => _options(context, ref, team),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Crear equipo'),
                        onPressed: () => context.push(Routes.teamEditor),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final on = context.onBackdrop;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.groups, size: 80, color: on),
            const SizedBox(height: 12),
            Text(
              'Crea tu primer equipo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: on,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Crear equipo'),
              onPressed: onCreate,
            ),
          ],
        ),
      ),
    );
  }
}

/// Un equipo de la lista: su distintivo, el nombre, los jugadores y el
/// historial.
class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team, required this.onOptions});

  final SavedTeam team;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(fontSize: 13, color: Color(0xFF6B5A86));
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: onOptions,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              TeamBadge(team: team, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    if (team.players.isNotEmpty)
                      Text(
                        team.players.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    const SizedBox(height: 4),
                    _History(team: team),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Opciones',
                icon: const Icon(Icons.more_vert, color: AppColors.ink),
                onPressed: onOptions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Partidas, victorias y mejor puntaje, como píldoras pequeñas.
class _History extends StatelessWidget {
  const _History({required this.team});

  final SavedTeam team;

  @override
  Widget build(BuildContext context) {
    Widget stat(IconData icon, String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        stat(
          Icons.sports_esports,
          '${team.played} ${team.played == 1 ? 'partida' : 'partidas'}',
          AppColors.purple,
        ),
        stat(
          Icons.emoji_events,
          '${team.wins} ${team.wins == 1 ? 'victoria' : 'victorias'}',
          AppColors.orange,
        ),
        stat(Icons.star, 'Mejor: ${team.best}', AppColors.green),
      ],
    );
  }
}
