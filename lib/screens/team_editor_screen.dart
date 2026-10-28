import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme.dart';
import '../widgets/config_section.dart';
import '../widgets/play_background.dart';
import '../widgets/team_badge.dart';

/// Crear o editar un equipo: nombre (obligatorio, sin repetir), color,
/// ícono o emoji y jugadores (opcional). Al guardar vuelve con el equipo,
/// para que la configuración lo marque.
class TeamEditorScreen extends ConsumerStatefulWidget {
  const TeamEditorScreen({super.key, this.team});

  /// El equipo que se edita, o null para crear uno nuevo.
  final SavedTeam? team;

  @override
  ConsumerState<TeamEditorScreen> createState() => _TeamEditorScreenState();
}

class _TeamEditorScreenState extends ConsumerState<TeamEditorScreen> {
  late final _name = TextEditingController(text: widget.team?.name);
  final _player = TextEditingController();
  late int _colorIndex =
      widget.team?.colorIndex ?? _firstFreeColor(ref.read(teamsProvider));
  late String? _iconKey = widget.team?.iconKey;
  late String? _emoji = widget.team == null ? '🦁' : widget.team!.emoji;
  late List<String> _players = [...?widget.team?.players];
  bool _showErrors = false;

  bool get _editing => widget.team != null;

  /// Un color que todavía no usa ningún equipo, para que se distingan.
  static int _firstFreeColor(AsyncValue<List<SavedTeam>> teams) {
    final used = {for (final t in teams.value ?? const []) t.colorIndex};
    for (var i = 0; i < SavedTeam.colors.length; i++) {
      if (!used.contains(i)) return i;
    }
    return 0;
  }

  @override
  void dispose() {
    _name.dispose();
    _player.dispose();
    super.dispose();
  }

  SavedTeam get _draft {
    final base =
        widget.team ??
        SavedTeam(id: TeamsController.newId(), name: _name.text.trim());
    return SavedTeam(
      id: base.id,
      name: _name.text.trim(),
      colorIndex: _colorIndex,
      iconKey: _iconKey,
      emoji: _iconKey == null ? _emoji : null,
      players: _players,
      played: base.played,
      wins: base.wins,
      best: base.best,
    );
  }

  /// El error del nombre, o null si está bien.
  String? get _nameError {
    final name = _name.text.trim();
    if (name.isEmpty) return 'Escribe un nombre';
    final taken = ref
        .read(teamsProvider.notifier)
        .nameTaken(name, exceptId: widget.team?.id);
    return taken ? 'Ya hay un equipo con ese nombre' : null;
  }

  void _addPlayer() {
    final name = _player.text.trim();
    if (name.isEmpty) return;
    setState(() {
      if (!_players.any((p) => p.toLowerCase() == name.toLowerCase())) {
        _players = [..._players, name];
      }
      _player.clear();
    });
  }

  Future<void> _save() async {
    // Lo que quedó escrito sin tocar "Agregar" también cuenta.
    if (_player.text.trim().isNotEmpty) _addPlayer();
    if (_nameError != null) {
      setState(() => _showErrors = true);
      return;
    }
    final team = _draft;
    await ref.read(teamsProvider.notifier).save(team);
    if (mounted) context.pop(team);
  }

  @override
  Widget build(BuildContext context) {
    // Para saber si el nombre se repite.
    ref.watch(teamsProvider);
    final draft = _draft;
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_editing ? 'Editar equipo' : 'Nuevo equipo'),
          leading: BackButton(onPressed: () => context.pop()),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Center(child: TeamBadge(team: draft, size: 96)),
              const SizedBox(height: 16),
              ConfigSection(
                icon: Icons.badge,
                title: 'Nombre',
                children: [
                  TextField(
                    key: const ValueKey('nombre-equipo'),
                    controller: _name,
                    maxLength: SavedTeam.maxNameLength,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Ej: Los Primos',
                      errorText: _showErrors ? _nameError : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ConfigSection(
                icon: Icons.palette,
                title: 'Color',
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < SavedTeam.colors.length; i++)
                        _ColorDot(
                          color: SavedTeam.colors[i],
                          selected: i == _colorIndex,
                          onTap: () => setState(() => _colorIndex = i),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ConfigSection(
                icon: Icons.emoji_emotions,
                title: 'Ícono o emoji',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in SavedTeam.emojis)
                        _BadgeChoice(
                          color: draft.color,
                          selected: _iconKey == null && _emoji == e,
                          onTap: () => setState(() {
                            _emoji = e;
                            _iconKey = null;
                          }),
                          child: Text(e, style: const TextStyle(fontSize: 24)),
                        ),
                      for (final entry in SavedTeam.icons.entries)
                        _BadgeChoice(
                          color: draft.color,
                          selected: _iconKey == entry.key,
                          onTap: () => setState(() => _iconKey = entry.key),
                          child: Icon(
                            entry.value,
                            color: _iconKey == entry.key
                                ? draft.onColor
                                : context.surfaces.onCard,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ConfigSection(
                icon: Icons.person_add,
                title: 'Jugadores (opcional)',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('jugador'),
                          controller: _player,
                          maxLength: SavedTeam.maxPlayerLength,
                          textCapitalization: TextCapitalization.words,
                          onSubmitted: (_) => _addPlayer(),
                          decoration: const InputDecoration(
                            hintText: 'Nombre de un jugador',
                            counterText: '',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Agregar',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.purple,
                        ),
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: _addPlayer,
                      ),
                    ],
                  ),
                  if (_players.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final p in _players)
                          InputChip(
                            label: Text(p),
                            onDeleted: () => setState(
                              () => _players = [
                                for (final x in _players)
                                  if (x != p) x,
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: Text(_editing ? 'Guardar cambios' : 'Crear equipo'),
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? context.surfaces.onCard : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check,
                color: color == AppColors.yellow ? AppColors.ink : Colors.white,
                size: 22,
              )
            : null,
      ),
    );
  }
}

class _BadgeChoice extends StatelessWidget {
  const _BadgeChoice({
    required this.color,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : context.surfaces.chip,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }
}
