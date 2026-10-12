import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme.dart';

/// Estado del televisor para el Modo TV. Conectado: "Modo TV activado" y el
/// botón para desconectarlo. Sin conectar: "Jugar en un TV" y el enlace con
/// los pasos para conectarlo.
class TvConnect extends ConsumerWidget {
  const TvConnect({super.key, this.light = false});

  /// Verdadero sobre el fondo de color del juego; falso sobre la tarjeta
  /// blanca de la configuración.
  final bool light;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(tvConnectedProvider).value ?? false;
    final ink = light ? context.onBackdrop : AppColors.ink;
    final accent = light ? context.onBackdrop : AppColors.purple;
    final row = Row(
      children: [
        Icon(
          Icons.tv,
          color: connected ? AppColors.green : ink.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            connected ? 'Modo TV activado' : 'Jugar en un TV',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ),
        if (connected) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ink.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_off, size: 14, color: ink),
                const SizedBox(width: 4),
                Text(
                  'Sin video',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
    if (!connected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row,
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle: const TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
              ),
            ),
            icon: const Icon(Icons.cast, size: 20),
            label: const Text('¿Cómo conectar un TV?'),
            onPressed: () => showTvSteps(context),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.cancel_presentation),
          label: const Text('Desconectar TV'),
          // El botón del tema va con el color del fondo; sobre la tarjeta
          // blanca de la configuración va en morado.
          style: light
              ? null
              : OutlinedButton.styleFrom(
                  foregroundColor: AppColors.purple,
                  side: const BorderSide(color: AppColors.purple, width: 2),
                  textStyle: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          onPressed: () => disconnectTv(context, ref),
        ),
      ],
    );
  }
}

/// Pasos para conectar el celular a un televisor, según el sistema.
List<String> get _connectSteps => Platform.isIOS
    ? const [
        'Abre el Centro de control',
        'Toca "Duplicar pantalla"',
        'Elige tu Apple TV o TV con AirPlay',
      ]
    : const [
        'Baja los ajustes rápidos',
        'Toca "Transmitir pantalla" o "Smart View"',
        'Elige tu televisor',
      ];

/// Pasos para dejar de duplicar la pantalla.
List<String> get _disconnectSteps => Platform.isIOS
    ? const [
        'Abre el Centro de control',
        'Toca "Duplicar pantalla"',
        'Toca "Detener duplicación"',
      ]
    : const [
        'Baja los ajustes rápidos',
        'Toca "Transmitir pantalla" o "Smart View"',
        'Toca "Desconectar"',
      ];

/// Muestra desde abajo los pasos para conectar un televisor.
Future<void> showTvSteps(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => TvStepsSheet(
    title: 'Conectar a un televisor',
    steps: _connectSteps,
    note: Platform.isIOS ? null : 'También sirve un cable HDMI',
  ),
);

/// Abre la lista de televisores del sistema. Si el sistema no tiene una,
/// como en iPhone, muestra los pasos.
Future<void> connectTv(BuildContext context, WidgetRef ref) async {
  final opened = await ref.read(tvServiceProvider).openSettings();
  if (opened || !context.mounted) return;
  await showTvSteps(context);
}

/// Deja de duplicar la pantalla. Si el sistema no lo permite desde la app,
/// como en iPhone, muestra los pasos.
Future<void> disconnectTv(BuildContext context, WidgetRef ref) async {
  final done = await ref.read(tvServiceProvider).disconnect();
  if (done || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) =>
        TvStepsSheet(title: 'Desconectar el TV', steps: _disconnectSteps),
  );
}

/// Ventana de pasos numerados en círculos de colores, con "Entendido".
class TvStepsSheet extends StatelessWidget {
  const TvStepsSheet({
    super.key,
    required this.title,
    required this.steps,
    this.note,
  });

  final String title;
  final List<String> steps;

  /// Una línea pequeña al final, como "También sirve un cable HDMI".
  final String? note;

  static const _colors = [
    AppColors.purple,
    AppColors.turquoise,
    AppColors.orange,
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
            Text(
              title,
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _colors[i % _colors.length],
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (note != null) ...[
              const SizedBox(height: 4),
              Text(
                note!,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B5A86)),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      ),
    );
  }
}
