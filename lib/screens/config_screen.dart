import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../widgets/number_stepper.dart';
import '../widgets/option_selector.dart';
import '../widgets/play_background.dart';
import '../widgets/word_suggestion.dart';

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

  void _setGroupCount(int count) {
    setState(() {
      while (_names.length < count) {
        _names.add(TextEditingController(text: 'Grupo ${_names.length + 1}'));
      }
      while (_names.length > count) {
        _names.removeLast().dispose();
      }
    });
  }

  void _continue() {
    final groups = [
      for (var i = 0; i < _names.length; i++)
        Group(
          _names[i].text.trim().isEmpty
              ? 'Grupo ${i + 1}'
              : _names[i].text.trim(),
        ),
    ];
    ref
        .read(gameControllerProvider.notifier)
        .configure(_config.copyWith(groups: groups));
    context.go(Routes.words);
  }

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(premiumUnlockedProvider);
    const gap = SizedBox(height: 16);
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Configuración'),
          leading: BackButton(onPressed: () => context.go(Routes.categories)),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              PlayPanel(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    NumberStepper(
                      label: 'Grupos',
                      value: _names.length,
                      min: GameConfig.minGroups,
                      max: GameConfig.maxGroups,
                      onChanged: _setGroupCount,
                    ),
                    NumberStepper(
                      label: 'Rondas',
                      value: _config.rounds,
                      min: GameConfig.minRounds,
                      max: GameConfig.maxRounds,
                      onChanged: (v) =>
                          setState(() => _config = _config.copyWith(rounds: v)),
                    ),
                    NumberStepper(
                      label: 'Tiempo por turno',
                      value: _config.turnDuration.inSeconds,
                      min: GameConfig.minTurnSeconds,
                      max: GameConfig.maxTurnSeconds,
                      step: 15,
                      format: (v) => '$v s',
                      onChanged: (v) => setState(
                        () => _config = _config.copyWith(
                          turnDuration: Duration(seconds: v),
                        ),
                      ),
                    ),
                    NumberStepper(
                      label: 'Palabras por grupo',
                      value: _config.wordsPerGroup,
                      min: GameConfig.minWordsPerGroup,
                      max: GameConfig.maxWordsPerGroup,
                      onChanged: (v) => setState(
                        () => _config = _config.copyWith(wordsPerGroup: v),
                      ),
                    ),
                    WordSuggestion(
                      config: _config,
                      onUse: (v) => setState(
                        () => _config = _config.copyWith(wordsPerGroup: v),
                      ),
                    ),
                  ],
                ),
              ),
              gap,
              PlayPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nombres de los grupos',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < _names.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: _names[i],
                          maxLength: 20,
                          decoration: InputDecoration(
                            labelText: 'Grupo ${i + 1}',
                            counterText: '',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              gap,
              PlayPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OptionSelector<ScoringMode>(
                      label: 'Puntuación',
                      options: ScoringMode.values,
                      selected: _config.scoringMode,
                      labelOf: (o) => o.label,
                      description: _config.scoringMode.description,
                      onSelected: (o) => setState(
                        () => _config = _config.copyWith(scoringMode: o),
                      ),
                    ),
                    const SizedBox(height: 20),
                    OptionSelector<HitMode>(
                      label: 'Cómo marcar los aciertos',
                      options: HitMode.values,
                      selected: _config.hitMode,
                      labelOf: (o) => o.label,
                      lockReasonOf: (o) => o.available ? null : 'Próximamente',
                      onSelected: (o) => setState(
                        () => _config = _config.copyWith(hitMode: o),
                      ),
                    ),
                    const SizedBox(height: 20),
                    OptionSelector<VideoResolution>(
                      label: 'Resolución del video',
                      options: VideoResolution.values,
                      selected: _config.resolution,
                      labelOf: (o) => o.label,
                      lockReasonOf: (o) =>
                          o.premium && !premium ? 'Premium' : null,
                      description: 'Si tu celular no soporta la resolución elegida, se usa la más cercana.',
                      onSelected: (o) => setState(
                        () => _config = _config.copyWith(resolution: o),
                      ),
                    ),
                  ],
                ),
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
}
