import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/config_section.dart';
import '../widgets/number_stepper.dart';
import '../widgets/option_selector.dart';
import '../widgets/play_mode_selector.dart';
import '../widgets/play_background.dart';
import '../widgets/tv_connect.dart';
import '../widgets/words_reminder.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  late GameConfig _config;
  final List<TextEditingController> _names = [];

  @override
  void initState() {
    super.initState();
    _config = ref.read(gameControllerProvider).config;
    if (_automatic && !_noDifficulty) {
      // Las palabras vienen mezcladas.
      _difficulty = Difficulty.mixed;
      _config = _config.copyWith(difficulty: _difficulty);
    }
    for (final group in _config.groups) {
      _names.add(TextEditingController(text: group.name));
    }
    // Si es una partida nueva (sin nombres), se llena con la última
    // configuración guardada.
    if (_names.every((c) => c.text.trim().isEmpty)) _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await ref.read(configStoreProvider).load();
    if (saved == null || !mounted) return;
    setState(() {
      final names = saved.groupNames.take(GameConfig.maxGroups).toList();
      if (names.length >= GameConfig.minGroups) {
        while (_names.length < names.length) {
          _names.add(TextEditingController());
        }
        while (_names.length > names.length) {
          _names.removeLast().dispose();
        }
        for (var i = 0; i < names.length; i++) {
          _names[i].text = names[i];
        }
      }
      _config = _config.copyWith(
        groups: [for (final c in _names) Group(c.text.trim())],
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
      _hitMode = saved.hitMode;
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
            // Sin grupos se conservan los nombres de la vez anterior.
            groupNames: [for (final c in _names) c.text.trim()],
            rounds: config.rounds,
            turnDuration: config.turnDuration,
            wordsPerGroup: config.wordsPerGroup,
            scoringMode: _scoring ?? ScoringMode.perPhrase,
            hitMode: _hitMode ?? HitMode.tilt,
            resolution: config.resolution,
            difficulty: _automatic && !_noDifficulty ? _difficulty : null,
          ),
        )
        .ignore();
  }

  @override
  void dispose() {
    for (final controller in _names) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Verdadero después de tocar "Continuar" con algo sin completar.
  bool _showErrors = false;

  // Vienen marcadas por defecto: puntuación por frase, aciertos con
  // movimiento, dificultad Mezcladas y video HD. Se pueden cambiar.
  ScoringMode? _scoring = ScoringMode.perPhrase;
  HitMode? _hitMode = HitMode.tilt;

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
  /// juez marca con botones y no se graba, así que las secciones de
  /// aciertos y de video no se muestran.
  bool get _tvMode => ref.read(tvConnectedProvider).value ?? false;

  /// Lo que falta elegir, para el aviso al tocar "Continuar".
  List<String> get _missingChoices => [
    if (_automatic && !_noDifficulty && _difficulty == null) 'la dificultad',
    if (_scoring == null) 'la puntuación',
    if (!_tvMode && _hitMode == null) 'cómo se marcan los aciertos',
  ];

  String? _choiceError(Object? choice) =>
      _showErrors && choice == null ? 'Elijan una opción' : null;

  void _setGroupCount(int count) {
    setState(() {
      while (_names.length < count) {
        _names.add(TextEditingController());
      }
      while (_names.length > count) {
        _names.removeLast().dispose();
      }
      _config = _config.copyWith(
        groups: [for (final c in _names) Group(c.text.trim())],
      );
    });
  }

  /// "Configuración aleatoria": el juego pone los nombres de los grupos y
  /// elige el resto al azar, con valores que tienen sentido para la
  /// cantidad de grupos. Cada toque da una configuración nueva.
  void _autoFill() {
    final result = AutoFill.pick(
      _config,
      groups: _names.length,
      previousNames: [for (final c in _names) c.text],
    );
    setState(() {
      _config = result.config;
      for (var i = 0; i < result.names.length; i++) {
        _names[i].text = result.names[i];
      }
      _scoring = result.scoring;
      _hitMode = result.hitMode;
      _difficulty = result.difficulty;
      _showErrors = false;
    });
  }

  void _continue() {
    final missingNames = _inGroups && _names.any((c) => c.text.trim().isEmpty);
    final missing = _missingChoices;
    if (missingNames || missing.isNotEmpty) {
      setState(() => _showErrors = true);
      final message = missingNames
          ? 'Escriban el nombre de cada grupo.'
          : 'Elijan ${_joinList(missing)}.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    final groups = _inGroups
        ? [for (final c in _names) Group(c.text.trim())]
        : const [Group('')];
    _save(_config.copyWith(groups: groups));
    ref
        .read(gameControllerProvider.notifier)
        .configure(
          _config.copyWith(
            groups: groups,
            scoringMode: _scoring,
            hitMode: _tvMode ? HitMode.tv : _hitMode,
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
              // Lo primero: sin grupos (viene elegido) o en grupos.
              Text(
                '¿Cómo van a jugar?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: context.onBackdrop,
                ),
              ),
              const SizedBox(height: 10),
              PlayModeSelector(
                inGroups: _inGroups,
                onChanged: (v) => _update(_config.copyWith(inGroups: v)),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Configuración aleatoria'),
                onPressed: _autoFill,
              ),
              SizedBox(height: 6),
              Text(
                _inGroups
                    ? 'El juego pone los nombres de los grupos y elige la '
                          'configuración por ti. Tócalo otra vez para '
                          'cambiarla.'
                    : 'El juego elige la configuración por ti. Tócalo otra '
                          'vez para cambiarla.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.onBackdrop,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              gap,
              if (_inGroups) ...[
                ConfigSection(
                  icon: Icons.groups,
                  title: 'Grupos',
                  children: [
                    ConfigRow(
                      label: 'Número de grupos',
                      hint: 'Hasta ${GameConfig.maxGroups} grupos.',
                      child: NumberStepper(
                        value: _names.length,
                        min: GameConfig.minGroups,
                        max: GameConfig.maxGroups,
                        onChanged: _setGroupCount,
                      ),
                    ),
                    _nameFields(),
                  ],
                ),
                gap,
              ],
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
                    title: 'Palabras por grupo',
                    children: [
                      const Text(
                        'Antes de empezar, cada grupo escribirá sus propias '
                        'palabras o frases secretas para los demás grupos. '
                        '¿Cuántas pondrá cada grupo?',
                      ),
                      ConfigRow(
                        label: 'Palabras o frases por grupo',
                        child: NumberStepper(
                          value: _config.wordsPerGroup,
                          min: GameConfig.minWordsPerGroup,
                          max: GameConfig.maxWordsPerGroup,
                          onChanged: (v) =>
                              _update(_config.copyWith(wordsPerGroup: v)),
                        ),
                      ),
                      Text(
                        'En total se jugará con ${_config.totalWords} palabras '
                        'o frases.',
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
                      hint: _inGroups
                          ? 'Cada grupo juega un turno por ronda.'
                          : 'Un turno por ronda.',
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
                  icon: Icons.swap_vert,
                  title: 'Aciertos',
                  children: [
                    OptionSelector<HitMode>(
                      label: 'Cómo se marcan los aciertos',
                      options: HitMode.selectable,
                      selected: _hitMode,
                      errorText: _choiceError(_hitMode),
                      labelOf: (o) => o.label,
                      lockReasonOf: (o) => o.available ? null : 'Próximamente',
                      description: _hitMode?.description,
                      onSelected: (o) => setState(() => _hitMode = o),
                    ),
                  ],
                ),
                gap,
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
                          o.premium && !premium ? 'Premium' : null,
                      description:
                          'Si tu celular no soporta la resolución elegida, '
                          'se usa la más cercana.',
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
      children: [
        Text(
          _tvMode
              ? 'Modo TV activado: la palabra, el tiempo y el marcador se ven '
                    'en el TV y un juez marca "Pasar" y "¡Correcto!" con '
                    'botones. No se graba video.'
              : 'Duplica la pantalla de tu celular en cualquier TV para jugar '
                    'en Modo TV: un juez marca con botones y no se graba video.',
        ),
        const TvConnect(),
      ],
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
          description: _difficulty?.description,
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
          hint: 'Cada turno dura hasta que se acabe el tiempo.',
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

  /// Un campo de nombre por grupo, uno debajo del otro.
  Widget _nameFields() {
    return Column(
      children: [
        for (var i = 0; i < _names.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
            child: _nameField(i),
          ),
      ],
    );
  }

  Widget _nameField(int i) {
    final empty = _names[i].text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: 'Nombre del grupo ${i + 1} ',
            children: const [
              TextSpan(
                text: '*',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _names[i],
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Ej: Los Invencibles',
            counterText: '',
            isDense: true,
            errorText: _showErrors && empty ? 'Escribe un nombre' : null,
          ),
        ),
      ],
    );
  }
}
