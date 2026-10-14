import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets/play_background.dart';

/// "Ajustes": preferencias de juego, apariencia y ayuda. Todo se guarda en
/// el celular y se aplica desde que abre la app.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    void update(AppSettings s) => ref.read(settingsProvider.notifier).update(s);
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Ajustes')),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              _Section(
                title: 'Preferencias de juego',
                rows: [
                  _SwitchRow(
                    icon: Icons.music_note,
                    color: AppColors.magenta,
                    title: 'Música',
                    value: settings.music,
                    onChanged: (v) => update(settings.copyWith(music: v)),
                  ),
                  _SwitchRow(
                    icon: Icons.volume_up,
                    color: AppColors.orange,
                    title: 'Efectos de sonido',
                    value: settings.sounds,
                    onChanged: (v) => update(settings.copyWith(sounds: v)),
                  ),
                  _SwitchRow(
                    icon: Icons.vibration,
                    color: AppColors.green,
                    title: 'Vibración',
                    value: settings.vibration,
                    onChanged: (v) => update(settings.copyWith(vibration: v)),
                  ),
                  _SwitchRow(
                    icon: Icons.screen_rotation,
                    color: AppColors.blue,
                    title: 'Rotación invertida',
                    value: settings.invertedRotation,
                    onChanged: (v) =>
                        update(settings.copyWith(invertedRotation: v)),
                  ),
                  _ControllerRow(
                    value: settings.controller,
                    onChanged: (c) => update(settings.copyWith(controller: c)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _Section(
                title: 'Apariencia',
                rows: [
                  _LinkRow(
                    icon: Icons.palette,
                    color: AppColors.purple,
                    title: 'Fondos',
                    onTap: () => context.push(Routes.backdrops),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _Section(
                title: 'Ayuda',
                rows: [
                  _LinkRow(
                    icon: Icons.help_outline,
                    color: AppColors.turquoise,
                    title: 'Cómo se juega',
                    onTap: () => context.push(Routes.welcome),
                  ),
                  _LinkRow(
                    icon: Icons.favorite_border,
                    color: AppColors.coral,
                    title: 'Créditos',
                    onTap: () => showCredits(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un título sobre el fondo y una tarjeta blanca con sus filas.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.onBackdrop,
            ),
          ),
        ),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: 64,
                    color: Color(0xFFEDE6F8),
                  ),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// El ícono de una fila, en un cuadro de color.
class _RowIcon extends StatelessWidget {
  const _RowIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

const _rowTitle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w800,
  color: AppColors.ink,
);

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: _RowIcon(icon: icon, color: color),
      title: Text(title, style: _rowTitle),
      value: value,
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.green,
      onChanged: onChanged,
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _RowIcon(icon: icon, color: color),
      title: Text(title, style: _rowTitle),
      trailing: const Icon(Icons.chevron_right, color: AppColors.ink),
      onTap: onTap,
    );
  }
}

/// "Controlador": Inclinación o Toque, como dos botones de radio.
class _ControllerRow extends StatelessWidget {
  const _ControllerRow({required this.value, required this.onChanged});

  final PlayController value;
  final ValueChanged<PlayController> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              _RowIcon(icon: Icons.sports_esports, color: AppColors.indigo),
              SizedBox(width: 16),
              Text('Controlador', style: _rowTitle),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final c in PlayController.values) ...[
                if (c != PlayController.values.first) const SizedBox(width: 10),
                Expanded(
                  child: _ControllerOption(
                    controller: c,
                    selected: c == value,
                    onTap: () => onChanged(c),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ControllerOption extends StatelessWidget {
  const _ControllerOption({
    required this.controller,
    required this.selected,
    required this.onTap,
  });

  final PlayController controller;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.ink;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Material(
        color: selected ? AppColors.purple : const Color(0xFFF4EEFD),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Column(
              children: [
                Icon(
                  controller == PlayController.tilt
                      ? Icons.screen_rotation_alt
                      : Icons.touch_app,
                  color: color,
                ),
                const SizedBox(height: 4),
                Text(
                  controller.label,
                  style: TextStyle(fontWeight: FontWeight.w800, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Muestra desde abajo los créditos de la música, los efectos y las imágenes.
Future<void> showCredits(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => const CreditsSheet(),
);

/// Créditos: de dónde salen la música, los efectos de sonido y las
/// imágenes de las categorías.
class CreditsSheet extends StatelessWidget {
  const CreditsSheet({super.key});

  static const credits = [
    (
      Icons.music_note,
      AppColors.purple,
      'Música',
      '"Comedy" de nastelbom, en Pixabay (pixabay.com), con la Licencia de '
          'contenido de Pixabay.',
    ),
    (
      Icons.volume_up,
      AppColors.orange,
      'Efectos de sonido',
      'Toque de los botones de vadim_makes_sound, "¡Correcto!" de '
          'freesound_gamestudio, "Paso" de soynoviembre, la cuenta '
          'regresiva de transcendedlifting, el reloj de sspsurvival, la '
          'marimba del final de universfield y la ruleta de victorabdo, en '
          'Pixabay (pixabay.com), con la Licencia de contenido de Pixabay.',
    ),
    (
      Icons.image,
      AppColors.turquoise,
      'Imágenes de las categorías',
      'Íconos de Flaticon (flaticon.com), hechos por sus autores; el de '
          'Anime, por smalllikeart, y el de Futbolistas, por justicon.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3D7F7),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Créditos',
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            for (final (icon, color, title, text) in credits)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RowIcon(icon: icon, color: color),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: _rowTitle),
                          const SizedBox(height: 2),
                          Text(
                            text,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B5A86),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }
}
