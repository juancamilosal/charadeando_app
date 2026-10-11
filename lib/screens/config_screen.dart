import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../services/services.dart';
import '../widgets/config_section.dart';
import '../widgets/number_stepper.dart';
import '../widgets/option_selector.dart';
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
    for (final group in _config.groups) {
      _names.add(TextEditingController(text: group.name));
    }
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

  // Opciones que el usuario debe elegir: ninguna viene marcada. La
  // resolución del video sí tiene valor por defecto.
  GameEnd? _gameEnd;
  ScoringMode? _scoring;
  HitMode? _hitMode;

  /// Dificultad de las palabras automáticas. Las manuales no tienen.
  Difficulty? _difficulty;

  bool get _automatic => _config.wordSource == WordSource.random;

  /// Modo TV: el celular está duplicando la pantalla en un televisor. El
  /// juez marca con botones y no se graba, así que las secciones de
  /// aciertos y de video no se muestran.
  bool get _tvMode => ref.read(tvConnectedProvider).value ?? false;

  /// Lo que falta elegir, para el aviso al tocar "Continuar".
  List<String> get _missingChoices => [
    if (_automatic && _difficulty == null) 'la dificultad',
    if (_automatic && _gameEnd == null) 'la duración del juego',
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

  /// Llena la configuración con los valores de prueba, para no escribirlos
  /// en cada prueba.
  void _fillTestData() {
    final names = [for (final g in TestData.config.groups) g.name];
    _setGroupCount(names.length);
    setState(() {
      _config = TestData.config.copyWith(
        resolution: _config.resolution,
        wordSource: _config.wordSource,
        category: _config.category,
      );
      for (var i = 0; i < names.length; i++) {
        _names[i].text = names[i];
      }
      _gameEnd = _config.gameEnd;
      _scoring = _config.scoringMode;
      _hitMode = _config.hitMode;
      _difficulty ??= Difficulty.normal;
      _showErrors = false;
    });
  }

  void _continue() {
    final missingNames = _names.any((c) => c.text.trim().isEmpty);
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
    final groups = [for (final c in _names) Group(c.text.trim())];
    ref
        .read(gameControllerProvider.notifier)
        .configure(
          _config.copyWith(
            groups: groups,
            gameEnd: _gameEnd,
            scoringMode: _scoring,
            hitMode: _tvMode ? HitMode.tv : _hitMode,
            difficulty: _automatic ? _difficulty : null,
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
              _config.category == GameCategory.free
                  ? Routes.freeMode
                  : Routes.categoryIntro,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (TestData.enabled) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.science),
                  label: const Text('Rellenar datos de prueba'),
                  onPressed: _fillTestData,
                ),
                gap,
              ],
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
              if (automatic) ...[
                _durationSection(),
                gap,
                // Por número de rondas se traen las palabras que alcancen:
                // no se elige la cantidad.
                if (_gameEnd != GameEnd.rounds) ...[_autoWordsSection(), gap],
                _difficultySection(),
                gap,
              ] else ...[
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
                ConfigSection(
                  icon: Icons.timer,
                  title: 'Partida',
                  children: [
                    ConfigRow(
                      label: 'Rondas',
                      hint: 'Cada grupo juega un turno por ronda.',
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
              _tvSection(),
              gap,
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
              if (automatic) ...[
                ConfigSection(
                  icon: Icons.hourglass_bottom,
                  title: 'Turnos',
                  children: [
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
          onSelected: (o) => setState(() => _difficulty = o),
        ),
      ],
    );
  }

  /// Cuántas palabras automáticas se juegan en total.
  Widget _autoWordsSection() {
    final perGroup = _config.autoWordsPerGroup;
    final leftover = _config.autoWordCount - perGroup * _config.groupCount;
    return ConfigSection(
      icon: _config.category.icon,
      title: _config.category == GameCategory.free
          ? 'Palabras'
          : 'Palabras: ${_config.category.label}',
      children: [
        const Text(
          'Nosotros ponemos las palabras al empezar la partida. ¿Cuántas '
          'quieren jugar?',
        ),
        ConfigRow(
          label: 'Palabras de la partida',
          child: NumberStepper(
            value: _config.autoWordCount,
            min: GameConfig.minAutoWords,
            max: GameConfig.maxAutoWords,
            step: 5,
            onChanged: (v) => _update(_config.copyWith(autoWordCount: v)),
          ),
        ),
        Text(
          leftover == 0
              ? 'Cada grupo tendrá $perGroup palabras.'
              : 'Cada grupo tendrá $perGroup palabras, para que todos '
                    'tengan las mismas.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B5A86)),
        ),
      ],
    );
  }

  /// Hasta que se acaben las palabras, o por número de rondas.
  Widget _durationSection() {
    final byRounds = _gameEnd == GameEnd.rounds;
    return ConfigSection(
      icon: Icons.timer,
      title: 'Duración del juego',
      children: [
        OptionSelector<GameEnd>(
          label: '¿Hasta cuándo juegan?',
          options: GameEnd.values,
          selected: _gameEnd,
          labelOf: (o) => o.label,
          description: _gameEnd?.description,
          errorText: _choiceError(_gameEnd),
          onSelected: (o) => setState(() => _gameEnd = o),
        ),
        if (byRounds)
          ConfigRow(
            label: 'Rondas',
            hint: 'Cada grupo juega un turno por ronda.',
            child: NumberStepper(
              value: _config.rounds,
              min: GameConfig.minRounds,
              max: GameConfig.maxRounds,
              onChanged: (v) => _update(_config.copyWith(rounds: v)),
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
