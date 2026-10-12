import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/punishments.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets/config_section.dart';
import '../widgets/number_stepper.dart';
import '../widgets/play_background.dart';
import '../widgets/punishment_roulette.dart';

/// Sección "Ruleta de castigos": arriba la ruleta, que se va armando a
/// medida que se eligen cuántos campos tiene y sus castigos, y debajo la
/// configuración. Al girar, la ruleta queda guardada en el celular para el
/// final de la partida.
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

  /// Castigos del juego para la vista previa: se eligen una vez, para que
  /// no cambien con cada letra que se escribe.
  late List<String> _systemPick = Roulette.systemPick(
    RouletteSetup.maxFields,
    _random,
  );

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
      if (saved.source == PunishmentSource.system) {
        // Los mismos castigos del juego que la última vez.
        _systemPick = [
          ...saved.punishments,
          ...Roulette.systemPick(
            RouletteSetup.maxFields,
            _random,
            exclude: saved.punishments,
          ),
        ].take(RouletteSetup.maxFields).toList();
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

  /// Lo que muestra la ruleta mientras se configura: lo escrito (los
  /// vacíos con "?") o los castigos del juego.
  List<String> get _preview => switch (_source) {
    PunishmentSource.system => _systemPick.take(_fields).toList(),
    PunishmentSource.own ||
    PunishmentSource.mixed => [for (final p in _written) p.isEmpty ? '?' : p],
    null => List.filled(_fields, '?'),
  };

  String? get _error {
    final source = _source;
    if (source == null) return 'Elijan de dónde salen los castigos';
    if (source == PunishmentSource.own && _written.any((p) => p.isEmpty)) {
      return 'Escriban los $_fields castigos.';
    }
    return null;
  }

  /// Algo cambió en la configuración: la ruleta vuelve a mostrarlo.
  void _changed(VoidCallback change) => setState(change);

  /// "Girar" (o soltarla con impulso): revisa que esté completa, fija los
  /// castigos (en "Jugadores y app", la app llena los vacíos), la guarda para
  /// el final de la partida y la gira a pantalla completa. Aquí la ruleta
  /// no gira: solo muestra lo que se va configurando.
  bool _beforeSpin(RouletteSpin spin) {
    final error = _error;
    if (error != null) {
      setState(() => _showErrors = true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return false;
    }
    final source = _source!;
    final written = _written;
    final setup = RouletteSetup(
      source: source,
      written: source.written ? written : const [],
      punishments: switch (source) {
        PunishmentSource.own => written,
        PunishmentSource.system => _systemPick.take(_fields).toList(),
        PunishmentSource.mixed => Roulette.completeMixed(
          written,
          _fields,
          _random,
        ),
      },
    );
    ref.read(punishmentStoreProvider).save(setup).ignore();
    // La de pantalla completa sigue el mismo giro: desde donde quedó y,
    // si fue con el dedo, hacia el mismo lado.
    context.push(Routes.punishmentSpin, extra: (setup.punishments, spin));
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Ruleta de castigos'),
          // Es una pestaña de la barra de abajo.
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, box) {
              final wheel = min(box.maxWidth - 40, 320.0);
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  // La ruleta con su botón "Girar".
                  SizedBox(
                    height: wheel + 72,
                    child: PunishmentRoulette(
                      punishments: _preview,
                      random: _random,
                      onBeforeSpin: _beforeSpin,
                      onDone: () {},
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._config(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _config() {
    final source = _source;
    final error = _showErrors ? _error : null;
    return [
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
              onChanged: (v) => _changed(() => _fields = v),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      ConfigSection(
        icon: Icons.gavel,
        title: 'Castigos',
        children: [
          // Una opción por línea, con lo que significa debajo.
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Text(
                '¿De dónde salen los castigos?',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              for (final s in PunishmentSource.values)
                _SourceOption(
                  source: s,
                  selected: s == source,
                  onTap: () => _changed(() => _source = s),
                ),
            ],
          ),
          if (source == null && error != null)
            Text(
              error,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (source == PunishmentSource.system)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.purple),
              icon: const Icon(Icons.shuffle),
              label: const Text('Otros castigos'),
              onPressed: () => _changed(
                () => _systemPick = Roulette.systemPick(
                  RouletteSetup.maxFields,
                  _random,
                  exclude: _systemPick.take(_fields),
                ),
              ),
            ),
          if (source != null && source.written)
            for (var i = 0; i < _fields; i++)
              TextField(
                key: ValueKey('castigo$i'),
                controller: _controllers[i],
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                // Cada letra se ve en la ruleta.
                onChanged: (_) => _changed(() {}),
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
    ];
  }
}

/// Ruleta de castigo de un grupo al final de la partida. Usa la ruleta
/// guardada en la sección; si nunca se configuró, 8 castigos del sistema.
class PunishmentSpinScreen extends ConsumerStatefulWidget {
  const PunishmentSpinScreen({
    super.key,
    this.groupName = '',
    this.punishments,
    this.random,
    this.startWith,
  });

  static const defaultFields = 8;

  /// El equipo que gira al final de la partida; vacío desde la sección
  /// Ruleta, que no lleva título: solo la ruleta y su botón.
  final String groupName;

  /// Los castigos con que se gira; si es null, los de la ruleta guardada.
  final List<String>? punishments;
  final Random? random;

  /// El giro que empezó en la sección Ruleta, para seguirlo igual.
  final RouletteSpin? startWith;

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
    final given = widget.punishments;
    if (given != null) {
      setState(() => _punishments = given);
      return;
    }
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
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.groupName.isNotEmpty) ...[
                  Text(
                    '¡Ruleta de castigo para ${widget.groupName}!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: context.onBackdrop,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: punishments == null
                      ? Center(
                          child: CircularProgressIndicator(
                            color: context.onBackdrop,
                          ),
                        )
                      : PunishmentRoulette(
                          punishments: punishments,
                          random: _random,
                          autoStart: true,
                          startWith: widget.startWith,
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

/// Una forma de elegir los castigos, en su propia línea: ícono, nombre y
/// qué significa.
class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final PunishmentSource source;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (source) {
    PunishmentSource.own => Icons.edit_rounded,
    PunishmentSource.system => Icons.auto_awesome_rounded,
    PunishmentSource.mixed => Icons.join_inner_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.purple : AppColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.purple.withValues(alpha: 0.08)
                : const Color(0xFFF7F4FD),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.purple : const Color(0xFFE4DCF5),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(_icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.label,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      source.hint,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.purple : const Color(0xFFB4B1E6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
