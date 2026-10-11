import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../services/punishments.dart';
import '../theme.dart';
import '../widgets/config_section.dart';
import '../widgets/number_stepper.dart';
import '../widgets/option_selector.dart';
import '../widgets/play_background.dart';
import '../widgets/punishment_roulette.dart';

/// Sección "Ruleta de castigos": se eligen cuántos campos tiene y de dónde
/// salen los castigos, y después se gira. La ruleta queda guardada en el
/// celular para el final de la partida.
class RouletteScreen extends ConsumerStatefulWidget {
  const RouletteScreen({super.key, this.random});

  final Random? random;

  @override
  ConsumerState<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends ConsumerState<RouletteScreen> {
  late final Random _random = widget.random ?? Random();
  final _controllers = [
    for (var i = 0; i < RouletteSetup.maxFields; i++) TextEditingController(),
  ];

  int _fields = 6;
  PunishmentSource? _source;
  bool _showErrors = false;

  /// Ruleta lista para girar; null mientras se configura.
  RouletteSetup? _setup;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await ref.read(punishmentStoreProvider).load();
    if (saved == null || !mounted) return;
    setState(() {
      _fields = saved.fields.clamp(
        RouletteSetup.minFields,
        RouletteSetup.maxFields,
      );
      _source = saved.source;
      for (
        var i = 0;
        i < saved.written.length && i < _controllers.length;
        i++
      ) {
        _controllers[i].text = saved.written[i];
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _written => [
    for (var i = 0; i < _fields; i++) _controllers[i].text.trim(),
  ];

  String? get _error {
    final source = _source;
    if (source == null) return 'Elijan de dónde salen los castigos.';
    if (source == PunishmentSource.own && _written.any((p) => p.isEmpty)) {
      return 'Escriban los $_fields castigos.';
    }
    return null;
  }

  Future<void> _goToWheel() async {
    if (_error != null) {
      setState(() => _showErrors = true);
      return;
    }
    final source = _source!;
    final written = _written;
    final setup = RouletteSetup(
      source: source,
      written: source.written ? written : const [],
      punishments: switch (source) {
        PunishmentSource.own => written,
        PunishmentSource.system => Roulette.systemPick(_fields, _random),
        PunishmentSource.mixed => Roulette.completeMixed(
          written,
          _fields,
          _random,
        ),
      },
    );
    await ref.read(punishmentStoreProvider).save(setup);
    if (mounted) setState(() => _setup = setup);
  }

  @override
  Widget build(BuildContext context) {
    final setup = _setup;
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Ruleta de castigos'),
          leading: BackButton(
            onPressed: () => setup == null
                ? context.go(Routes.categories)
                : setState(() => _setup = null),
          ),
        ),
        body: SafeArea(
          top: false,
          child: setup == null ? _configView() : _wheelView(setup),
        ),
      ),
    );
  }

  Widget _wheelView(RouletteSetup setup) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PunishmentRoulette(
              punishments: setup.punishments,
              random: _random,
              onDone: () => context.go(Routes.categories),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Cambiar castigos'),
            onPressed: () => setState(() => _setup = null),
          ),
        ],
      ),
    );
  }

  Widget _configView() {
    final source = _source;
    final error = _showErrors ? _error : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        const Text(
          'Una ruleta de colores con castigos para el grupo que pierde. '
          'Al final de la partida la gira el grupo con menos puntos.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        ConfigSection(
          icon: Icons.pie_chart,
          title: 'Campos de la ruleta',
          children: [
            ConfigRow(
              label: 'Cantidad de campos',
              hint: 'La ruleta se divide en partes iguales.',
              child: NumberStepper(
                value: _fields,
                min: RouletteSetup.minFields,
                max: RouletteSetup.maxFields,
                onChanged: (v) => setState(() => _fields = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ConfigSection(
          icon: Icons.gavel,
          title: 'Castigos',
          children: [
            OptionSelector<PunishmentSource>(
              label: 'Origen de los castigos',
              options: PunishmentSource.values,
              selected: source,
              labelOf: (s) => s.label,
              description: switch (source) {
                PunishmentSource.own => 'Escriban un castigo en cada campo.',
                PunishmentSource.system =>
                  'El juego elige castigos divertidos para todo público.',
                PunishmentSource.mixed =>
                  'Escriban los que quieran; el juego completa los vacíos.',
                null => null,
              },
              errorText: source == null ? error : null,
              onSelected: (s) => setState(() => _source = s),
            ),
            if (source != null && source.written)
              for (var i = 0; i < _fields; i++)
                TextField(
                  key: ValueKey('castigo$i'),
                  controller: _controllers[i],
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) {
                    if (_showErrors) setState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: source == PunishmentSource.mixed
                        ? 'Castigo ${i + 1} (opcional)'
                        : 'Castigo ${i + 1}',
                    counterText: '',
                    errorText:
                        error != null && _controllers[i].text.trim().isEmpty
                        ? 'Escriban este castigo'
                        : null,
                  ),
                ),
          ],
        ),
        if (error != null && source != null) ...[
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(
              color: AppColors.yellow,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Ir a la ruleta'),
          onPressed: _goToWheel,
        ),
      ],
    );
  }
}

/// Ruleta de castigo de un grupo al final de la partida. Usa la ruleta
/// guardada en la sección; si nunca se configuró, 8 castigos del sistema.
class PunishmentSpinScreen extends ConsumerStatefulWidget {
  const PunishmentSpinScreen({super.key, required this.groupName, this.random});

  static const defaultFields = 8;

  final String groupName;
  final Random? random;

  @override
  ConsumerState<PunishmentSpinScreen> createState() =>
      _PunishmentSpinScreenState();
}

class _PunishmentSpinScreenState extends ConsumerState<PunishmentSpinScreen> {
  late final Random _random = widget.random ?? Random();
  List<String>? _punishments;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await ref.read(punishmentStoreProvider).load();
    if (!mounted) return;
    setState(() {
      _punishments =
          saved?.punishments ??
          Roulette.systemPick(PunishmentSpinScreen.defaultFields, _random);
    });
  }

  @override
  Widget build(BuildContext context) {
    final punishments = _punishments;
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '¡Ruleta de castigo para ${widget.groupName}!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: punishments == null
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : PunishmentRoulette(
                          punishments: punishments,
                          random: _random,
                          autoStart: true,
                          onDone: () => context.pop(true),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
