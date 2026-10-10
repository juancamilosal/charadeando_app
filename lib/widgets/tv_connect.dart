import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme.dart';

/// Estado del televisor y el botón para conectarlo, para el Modo TV.
class TvConnect extends ConsumerWidget {
  const TvConnect({super.key, this.light = false});

  /// Verdadero sobre el fondo de color del juego: textos blancos.
  final bool light;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(tvConnectedProvider).value ?? false;
    final color = connected
        ? AppColors.green
        : (light ? AppColors.yellow : AppColors.coral);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(connected ? Icons.tv : Icons.tv_off, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                connected ? 'Conectado al televisor' : 'Televisor sin conectar',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: light ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.cast),
          label: const Text('Conectar las palabras a un televisor'),
          // El botón del tema es blanco, para el fondo de color; sobre la
          // tarjeta blanca de la configuración va en morado.
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
          onPressed: () => connectTv(context, ref),
        ),
      ],
    );
  }
}

/// Abre la lista de televisores del sistema. Si el sistema no tiene una,
/// como en iPhone, explica cómo duplicar la pantalla.
Future<void> connectTv(BuildContext context, WidgetRef ref) async {
  final opened = await ref.read(tvServiceProvider).openSettings();
  if (opened || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Conectar al televisor'),
      content: Text(
        Platform.isIOS
            ? 'Abre el Centro de control, toca "Duplicar pantalla" y elige '
                  'tu Apple TV o televisor con AirPlay.'
            : 'Desliza hacia abajo los ajustes rápidos, toca "Transmitir '
                  'pantalla" (o "Smart View") y elige tu Chromecast o '
                  'televisor. También sirve un cable HDMI.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
