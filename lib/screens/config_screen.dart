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
import '../widgets/words_warning.dart';

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

  /// Verdadero después de tocar "Continuar" con algún nombre vacío.
  bool _showNameErrors = false;

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
      _config = TestData.config.copyWith(resolution: _config.resolution);
      for (var i = 0; i < names.length; i++) {
        _names[i].text = names[i];
      }
      _showNameErrors = false;
    });
  }

  void _continue() {
    if (_names.any((c) => c.text.trim().isEmpty)) {
      setState(() => _showNameErrors = true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Escriban el nombre de cada grupo.')),
        );
      return;
    }
    final groups = [for (final c in _names) Group(c.text.trim())];
    ref
        .read(gameControllerProvider.notifier)
        .configure(_config.copyWith(groups: groups));
    context.go(Routes.words);
  }

  void _update(GameConfig config) => setState(() => _config = config);

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(premiumUnlockedProvider);
    const gap = SizedBox(height: 14);
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Configuración'),
          leading: BackButton(onPressed: () => context.go(Routes.freeMode)),
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
                  WordsWarning(config: _config),
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
              ConfigSection(
                icon: Icons.emoji_events,
                title: 'Puntuación',
                children: [
                  OptionSelector<ScoringMode>(
                    label: 'Cómo se cuentan los puntos',
                    options: ScoringMode.values,
                    selected: _config.scoringMode,
                    labelOf: (o) => o.label,
                    description: _config.scoringMode.description,
                    onSelected: (o) =>
                        _update(_config.copyWith(scoringMode: o)),
                  ),
                ],
              ),
              gap,
              ConfigSection(
                icon: Icons.swap_vert,
                title: 'Aciertos',
                children: [
                  OptionSelector<HitMode>(
                    label: 'Cómo se marcan los aciertos',
                    options: HitMode.values,
                    selected: _config.hitMode,
                    labelOf: (o) => o.label,
                    lockReasonOf: (o) => o.available ? null : 'Próximamente',
                    onSelected: (o) => _update(_config.copyWith(hitMode: o)),
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
                        'Si tu celular no soporta la resolución elegida, se '
                        'usa la más cercana.',
                    onSelected: (o) => _update(_config.copyWith(resolution: o)),
                  ),
                ],
              ),
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

  /// Campos de nombre de dos en dos, como en una tabla.
  Widget _nameFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: 12,
          children: [
            for (var i = 0; i < _names.length; i++)
              SizedBox(width: width, child: _nameField(i)),
          ],
        );
      },
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
            hintText: 'Ej: Los Tigres',
            counterText: '',
            isDense: true,
            errorText: _showNameErrors && empty ? 'Escribe un nombre' : null,
          ),
        ),
      ],
    );
  }
}
