import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/category_header.dart';
import '../widgets/config_section.dart';
import '../widgets/number_stepper.dart';
import '../widgets/option_selector.dart';
import '../widgets/play_mode_selector.dart';
import '../widgets/play_background.dart';
import '../widgets/premium_sheet.dart';
import '../widgets/tv_connect.dart';
import '../widgets/team_badge.dart';
import '../widgets/words_reminder.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  late GameConfig _config;

  /// Equipos elegidos, en el orden en que juegan: guardados en "Equipos"
  /// (con su id) o de esta partida (de la configuración aleatoria).
  List<Group> _teams = [];

  @override
  void initState() {
    super.initState();
    _config = ref.read(gameControllerProvider).config;
    if (_automatic && !_noDifficulty) {
      // Las palabras vienen mezcladas.
      _difficulty = Difficulty.mixed;
      _config = _config.copyWith(difficulty: _difficulty);
    }
    _teams = [
      for (final g in _config.groups)
        if (g.name.trim().isNotEmpty) g,
    ];
    // Si es una partida nueva (sin equipos), se llena con la última
    // configuración guardada.
    if (_teams.isEmpty) _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await ref.read(configStoreProvider).load();
    if (saved == null || !mounted) return;
    // Los equipos guardados que se eligieron la última vez, si siguen.
    final teams = await ref.read(teamsProvider.future);
    if (!mounted) return;
    setState(() {
      _teams = [
        for (final id in saved.teamIds.take(GameConfig.maxGroups))
          for (final t in teams)
            if (t.id == id) Group(t.name, teamId: t.id),
      ];
      _config = _config.copyWith(
        rounds: saved.rounds.clamp(GameConfig.minRounds, GameConfig.maxRounds),
        turnDuration: Duration(
          seconds: saved.turnDuration.inSeconds.clamp(
            GameConfig.minTurnSeconds,
            GameConfig.maxTurnSeconds,
          ),
        ),
        wordsPerGroup: saved.wordsPerGroup.clamp(
          GameConfig.minWordsPerGroup,
          GameConfig.maxWordsPerGroup,
        ),
        resolution: saved.resolution,
      );
      _scoring = saved.scoringMode;
      if (_automatic && !_noDifficulty && saved.difficulty != null) {
        _difficulty = saved.difficulty;
        _config = _config.copyWith(difficulty: _difficulty);
      }
    });
  }

  /// Guarda la configuración para la próxima partida.
  void _save(GameConfig config) {
    ref
        .read(configStoreProvider)
        .save(
          SavedConfig(
            // Sin equipos se conservan los de la vez anterior.
            groupNames: [for (final t in _teams) t.name],
            teamIds: [
              for (final t in _teams)
                if (t.teamId != null) t.teamId!,
            ],
            rounds: config.rounds,
            turnDuration: config.turnDuration,
            wordsPerGroup: config.wordsPerGroup,
            scoringMode: _scoring ?? ScoringMode.perPhrase,
            hitMode: HitMode.tilt,
            resolution: config.resolution,
            difficulty: _automatic && !_noDifficulty ? _difficulty : null,
          ),
        )
        .ignore();
  }

  /// Verdadero después de tocar "Continuar" con algo sin completar.
  bool _showErrors = false;

  // Vienen marcadas por defecto: puntuación por frase, dificultad
  // Mezcladas y video HD. Se pueden cambiar. Cómo se marcan los aciertos
  // se elige en Ajustes > Controlador.
  ScoringMode? _scoring = ScoringMode.perPhrase;

  /// Dificultad de las palabras automáticas. Las manuales no tienen.
  Difficulty? _difficulty;

  bool get _automatic => _config.wordSource == WordSource.random;

  /// Se juega en grupos. Sin grupos no se piden nombres ni palabras por
  /// grupo.
  bool get _inGroups => _config.inGroups;

  /// Se juega una categoría propia: sus palabras no tienen dificultad.
  bool get _custom => _config.customCategory != null;

  /// Sin dificultad: las palabras son de categorías propias (en una mezcla,
  /// solo si no hay ninguna del juego).
  bool get _noDifficulty => !_config.usesDifficulty;

  /// Modo TV: el celular está duplicando la pantalla en un televisor. El
  /// juez marca con botones y no se graba, así que la sección de video no
  /// se muestra.
  bool get _tvMode => ref.read(tvConnectedProvider).value ?? false;

  /// Lo que falta elegir, para el aviso al tocar "Continuar".
  List<String> get _missingChoices => [
    if (_automatic && !_noDifficulty && _difficulty == null) 'la dificultad',
    if (_scoring == null) 'la puntuación',
  ];

  String? _choiceError(Object? choice) =>
      _showErrors && choice == null ? 'Elijan una opción' : null;

  /// Marca o desmarca un equipo guardado. Se juega en el orden en que se
  /// marcan.
  void _toggleTeam(SavedTeam team) {
    final i = _teams.indexWhere((t) => t.teamId == team.id);
    if (i >= 0) {
      setState(() => _teams = [..._teams]..removeAt(i));
      return;
    }
    if (_teams.length >= GameConfig.maxGroups) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Máximo ${GameConfig.maxGroups} equipos.'),
          ),
        );
      return;
    }
    setState(() => _teams = [..._teams, Group(team.name, teamId: team.id)]);
  }

  /// "Nuevo equipo": se crea en la misma pantalla de Equipos y vuelve
  /// marcado.
  Future<void> _newTeam() async {
    final team = await context.push<SavedTeam>(Routes.teamEditor);
    if (team == null || !mounted) return;
    if (!_teams.any((t) => t.teamId == team.id)) _toggleTeam(team);
  }

  /// Los equipos elegidos con el nombre que tienen ahora en "Equipos"; los
  /// que se borraron ya no cuentan.
  List<Group> _currentTeams(List<SavedTeam> saved) => [
    for (final t in _teams)
      if (t.teamId == null)
        t
      else
        for (final s in saved)
          if (s.id == t.teamId) Group(s.name, teamId: s.id),
  ];

  /// "Configuración aleatoria": el juego pone los nombres de los grupos y
  /// elige el resto al azar, con valores que tienen sentido para la
  /// cantidad de grupos. Cada toque da una configuración nueva.
  void _autoFill() {
    // Los equipos de la configuración aleatoria son solo de esta partida:
    // no se guardan en "Equipos".
    final result = AutoFill.pick(
      _config,
      groups: _teams.length,
      previousNames: [for (final t in _teams) t.name],
    );
    setState(() {
      _config = result.config;
      _teams = [for (final n in result.names) Group(n)];
      _scoring = result.scoring;
      _difficulty = result.difficulty;
      _showErrors = false;
    });
  }

  void _continue() {
    final teams = _currentTeams(ref.read(teamsProvider).value ?? const []);
    final missingNames = _inGroups && teams.length < GameConfig.minGroups;
    final missing = _missingChoices;
    if (missingNames || missing.isNotEmpty) {
      setState(() => _showErrors = true);
      final message = missingNames
          ? 'Elijan de ${GameConfig.minGroups} a ${GameConfig.maxGroups} equipos.'
          : 'Elijan ${_joinList(missing)}.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    final groups = _inGroups ? teams : const [Group('')];
    _save(_config.copyWith(groups: groups));
    ref
        .read(gameControllerProvider.notifier)
        .configure(
          _config.copyWith(
            groups: groups,
            scoringMode: _scoring,
            // Inclinación o toque se elige en Ajustes > Controlador.
            hitMode: _tvMode ? HitMode.tv : HitMode.tilt,
            difficulty: _automatic && !_noDifficulty ? _difficulty : null,
            clearDifficulty: _noDifficulty,
          ),
        );
    context.go(
      _config.wordSource == WordSource.random ? Routes.autoWords : Routes.words,
    );
  }

  /// "a", "a y b", "a, b y c".
  static String _joinList(List<String> items) => items.length == 1
      ? items.single
      : '${items.sublist(0, items.length - 1).join(', ')} y ${items.last}';

  void _update(GameConfig config) => setState(() => _config = config);

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(premiumUnlockedProvider);
    final automatic = _automatic;
    const gap = SizedBox(height: 14);
    // Se vuelve a dibujar al conectar o desconectar el TV, y se avisa.
    ref.watch(tvConnectedProvider);
    ref.listen(tvConnectedProvider, (previous, next) {
      final was = previous?.value ?? false;
      final now = next.value ?? false;
      // Solo al cambiar, no con el primer valor al abrir la pantalla.
      if (previous == null || !previous.hasValue || was == now) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              now
                  ? 'El TV ya está conectado a este celular: Modo TV activado'
                  : 'TV desconectado: se juega sin televisor',
            ),
          ),
        );
    });
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Configuración'),
          leading: BackButton(
            onPressed: () => context.go(
              _config.category == GameCategory.free &&
                      !_custom &&
                      !_config.isMix
                  ? Routes.freeMode
                  : Routes.categories,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              CategoryHeader(config: _config),
              const SizedBox(height: 16),
              // Lo primero: sin grupos (viene elegido) o en grupos.
              PlayModeSelector(
                inGroups: _inGroups,
                onChanged: (v) => _update(_config.copyWith(inGroups: v)),
              ),
              const SizedBox(height: 20),
              _RandomButton(onTap: _autoFill),
              gap,
              if (_inGroups) ...[_teamsSection(), gap],
              if (automatic) ...[
                _autoGameSection(),
                gap,
                // Las palabras propias no tienen dificultad.
                if (!_noDifficulty) ...[_difficultySection(), gap],
              ] else ...[
                // Sin grupos, las palabras se escriben en una sola lista.
                if (_inGroups) ...[
                  ConfigSection(
                    icon: Icons.edit_note,
                    title: 'Palabras por equipo',
                    children: [
                      const Text(
                        '¿Cuántas palabras escribe cada equipo?',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      ConfigRow(
                        label: 'Palabras o frases por equipo',
                        child: NumberStepper(
                          value: _config.wordsPerGroup,
                          min: GameConfig.minWordsPerGroup,
                          max: GameConfig.maxWordsPerGroup,
                          onChanged: (v) =>
                              _update(_config.copyWith(wordsPerGroup: v)),
                        ),
                      ),
                      Text(
                        '${_config.totalWords} en total',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B5A86),
                        ),
                      ),
                      const WordsReminder(),
                    ],
                  ),
                  gap,
                ],
                ConfigSection(
                  icon: Icons.timer,
                  title: 'Partida',
                  children: [
                    ConfigRow(
                      label: 'Rondas',
                      child: NumberStepper(
                        value: _config.rounds,
                        min: GameConfig.minRounds,
                        max: GameConfig.maxRounds,
                        onChanged: (v) => _update(_config.copyWith(rounds: v)),
                      ),
                    ),
                    ConfigRow(
                      label: 'Tiempo por turno',
                      child: NumberStepper(
                        value: _config.turnDuration.inSeconds,
                        min: GameConfig.minTurnSeconds,
                        max: GameConfig.maxTurnSeconds,
                        step: 15,
                        format: (v) => '$v\u00A0s',
                        onChanged: (v) => _update(
                          _config.copyWith(turnDuration: Duration(seconds: v)),
                        ),
                      ),
                    ),
                  ],
                ),
                gap,
              ],
              ConfigSection(
                icon: Icons.emoji_events,
                title: 'Puntuación',
                children: [
                  OptionSelector<ScoringMode>(
                    label: 'Cómo se cuentan los puntos',
                    options: ScoringMode.values,
                    selected: _scoring,
                    labelOf: (o) => o.label,
                    description: _scoring?.description,
                    errorText: _choiceError(_scoring),
                    onSelected: (o) => setState(() => _scoring = o),
                  ),
                ],
              ),
              gap,
              if (!_tvMode) ...[
                ConfigSection(
                  icon: Icons.videocam,
                  title: 'Video',
                  children: [
                    OptionSelector<VideoResolution>(
                      label: 'Resolución',
                      options: VideoResolution.values,
                      selected: _config.resolution,
                      labelOf: (o) => o.label,
                      lockReasonOf: (o) =>
                          o.premium && !premium ? 'Todo Charadeando' : null,
                      onLockedTap: (_) => showPremiumSheet(context),
                      onSelected: (o) =>
                          _update(_config.copyWith(resolution: o)),
                    ),
                  ],
                ),
              ],
              // El Modo TV va al final, después del video.
              if (!_tvMode) gap,
              _tvSection(),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continuar'),
                onPressed: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Modo TV: se activa solo si el celular duplica la pantalla en un TV.
  Widget _tvSection() {
    return ConfigSection(
      icon: Icons.tv,
      title: 'Modo TV',
      children: [const TvConnect()],
    );
  }

  /// Fácil, normal o difícil: qué palabras se traen de la categoría.
  Widget _difficultySection() {
    return ConfigSection(
      icon: Icons.speed,
      title: 'Dificultad',
      children: [
        OptionSelector<Difficulty>(
          label: '¿Qué tan difíciles las quieren?',
          options: Difficulty.values,
          selected: _difficulty,
          labelOf: (o) => o.label,
          errorText: _choiceError(_difficulty),
          onSelected: (o) => setState(() {
            _difficulty = o;
            _config = _config.copyWith(difficulty: o);
          }),
        ),
      ],
    );
  }

  /// Partida con palabras automáticas: rondas y tiempo por turno. El turno
  /// dura hasta que se acabe el tiempo, sin límite de palabras.
  Widget _autoGameSection() {
    return ConfigSection(
      icon: _config.isMix
          ? Icons.shuffle
          : _config.customCategory?.icon ?? _config.category.icon,
      title: _config.isMix
          ? _config.categoryLabel
          : _config.category == GameCategory.free && !_custom
          ? 'Partida'
          : 'Partida: ${_config.categoryLabel}',
      children: [
        ConfigRow(
          label: 'Rondas',
          child: NumberStepper(
            value: _config.rounds,
            min: GameConfig.minRounds,
            max: GameConfig.maxRounds,
            onChanged: (v) => _update(_config.copyWith(rounds: v)),
          ),
        ),
        ConfigRow(
          label: 'Tiempo por turno',
          child: NumberStepper(
            value: _config.turnDuration.inSeconds,
            min: GameConfig.minTurnSeconds,
            max: GameConfig.maxTurnSeconds,
            step: 15,
            format: (v) => '$v\u00A0s',
            onChanged: (v) =>
                _update(_config.copyWith(turnDuration: Duration(seconds: v))),
          ),
        ),
      ],
    );
  }

  /// "Equipos": se eligen de 2 a 4 de los guardados (tocar para marcar),
  /// con "Nuevo equipo" para crear otro. Los de la configuración aleatoria
  /// también se ven, marcados como de esta partida.
  Widget _teamsSection() {
    final saved = ref.watch(teamsProvider).value ?? const <SavedTeam>[];
    final chosen = _currentTeams(saved);
    final error = _showErrors && chosen.length < GameConfig.minGroups
        ? 'Elijan de ${GameConfig.minGroups} a ${GameConfig.maxGroups} '
              'equipos.'
        : null;
    int? order(String? teamId, String name) {
      final i = chosen.indexWhere(
        (t) => teamId != null ? t.teamId == teamId : t.name == name,
      );
      return i < 0 ? null : i + 1;
    }

    final temporary = [
      for (final t in chosen)
        if (t.teamId == null) t,
    ];
    return ConfigSection(
      icon: Icons.groups,
      title: 'Equipos',
      children: [
        Text(
          saved.isEmpty && temporary.isEmpty
              ? 'Creen sus equipos para jugar.'
              : 'Toquen de ${GameConfig.minGroups} a ${GameConfig.maxGroups} '
                    'equipos. Juegan en ese orden.',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        for (final t in temporary)
          _TeamChoice(
            name: t.name,
            badge: const CircleAvatar(
              backgroundColor: AppColors.ink,
              child: Icon(Icons.shuffle, color: Colors.white, size: 20),
            ),
            note: 'Solo esta partida',
            order: order(null, t.name),
            onTap: () => setState(
              () => _teams = [
                for (final x in _teams)
                  if (x.teamId != null || x.name != t.name) x,
              ],
            ),
          ),
        for (final team in saved)
          _TeamChoice(
            name: team.name,
            badge: TeamBadge(team: team, size: 40),
            order: order(team.id, team.name),
            onTap: () => _toggleTeam(team),
          ),
        if (error != null)
          Text(
            error,
            style: const TextStyle(
              color: AppColors.coral,
              fontWeight: FontWeight.w800,
            ),
          ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.purple,
            side: const BorderSide(color: AppColors.purple, width: 2),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Nuevo equipo'),
          onPressed: _newTeam,
        ),
      ],
    );
  }
}

/// Un equipo que se puede marcar para la partida. Marcado, lleva su número
/// de turno.
class _TeamChoice extends StatelessWidget {
  const _TeamChoice({
    required this.name,
    required this.badge,
    required this.order,
    required this.onTap,
    this.note,
  });

  final String name;
  final Widget badge;

  /// Su lugar en el orden de los turnos, o null si no está marcado.
  final int? order;
  final VoidCallback onTap;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final selected = order != null;
    return Semantics(
      checked: selected,
      child: Material(
        color: selected ? const Color(0xFFF1E8FF) : const Color(0xFFF8F5FD),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.purple : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                SizedBox.square(dimension: 40, child: badge),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      if (note != null)
                        Text(
                          note!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B5A86),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.purple : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? AppColors.purple
                          : const Color(0xFFCFC3E6),
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? Text(
                          '$order',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Configuración aleatoria": morado oscuro con el texto blanco, para que se
/// distinga del fondo y del botón amarillo "Continuar".
class _RandomButton extends StatelessWidget {
  const _RandomButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ink,
      elevation: 4,
      shadowColor: const Color(0x66000000),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Configuración aleatoria',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
