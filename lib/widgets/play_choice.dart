import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../services/services.dart';
import '../theme.dart';
import 'backdrop_tile.dart';
import 'category_header.dart';

/// Empieza una partida rápida con la categoría (o la mezcla) que está
/// configurada: se salta la configuración y no la cambia. Las palabras
/// manuales se escriben directo; las demás se piden al servidor.
Future<void> startQuickGame(BuildContext context, WidgetRef ref) async {
  final router = GoRouter.of(context);
  final saved = await ref.read(configStoreProvider).load();
  final tv = ref.read(tvConnectedProvider).value ?? false;
  final config = QuickGame.config(
    ref.read(gameControllerProvider).config,
    saved: saved,
    tv: tv,
  );
  ref.read(gameControllerProvider.notifier).configure(config);
  router.go(
    config.wordSource == WordSource.random ? Routes.autoWords : Routes.words,
  );
}

/// Las dos formas de jugar una categoría.
enum PlayChoice { quick, custom }

/// Muestra desde abajo la categoría configurada con "Partida rápida" y
/// "Personalizada", y sigue con la que se elija: la rápida empieza ya y la
/// personalizada va a la configuración.
Future<void> choosePlay(BuildContext context, WidgetRef ref) async {
  // Si venían de una partida rápida, se vuelve a la configuración de
  // siempre.
  final game = ref.read(gameControllerProvider.notifier);
  game.configure(QuickGame.custom(ref.read(gameControllerProvider).config));
  final choice = await showModalBottomSheet<PlayChoice>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const PlayChoiceSheet(),
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case PlayChoice.quick:
      await startQuickGame(context, ref);
    case PlayChoice.custom:
      context.go(Routes.config);
  }
}

class PlayChoiceSheet extends ConsumerWidget {
  const PlayChoiceSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backdrop = context.backdrop;
    final gradient = backdrop.gradient;
    final config = ref.watch(gameControllerProvider).config;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backdrop.color,
        gradient: gradient == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: backdrop.onColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CategoryHeader(config: config, artSize: 96),
              const SizedBox(height: 16),
              PlayChoiceCards(
                onQuick: () => Navigator.pop(context, PlayChoice.quick),
                onCustom: () => Navigator.pop(context, PlayChoice.custom),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Las dos formas de jugar, del mismo tamaño: lado a lado, o una debajo de
/// la otra si la pantalla mide menos de 340 px de ancho.
class PlayChoiceCards extends StatelessWidget {
  const PlayChoiceCards({
    super.key,
    required this.onQuick,
    required this.onCustom,
  });

  /// Ancho de pantalla desde el que van lado a lado.
  static const sideBySideWidth = 340.0;

  final VoidCallback onQuick;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final quick = _ChoiceCard(
      color: AppColors.orange,
      icon: Icons.bolt,
      title: 'Partida rápida',
      text: '1 minuto, sin configurar nada',
      onTap: onQuick,
    );
    final custom = _ChoiceCard(
      color: AppColors.purple,
      icon: Icons.settings,
      title: 'Personalizada',
      text: 'Equipos, rondas, video y ruleta',
      onTap: onCustom,
    );
    if (MediaQuery.sizeOf(context).width < sideBySideWidth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [quick, const SizedBox(height: 12), custom],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: quick),
          const SizedBox(width: 12),
          Expanded(child: custom),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: BackdropTile(
        color: color,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        builder: (on) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: on),
            const SizedBox(height: 6),
            // En una sola línea: si no cabe, la letra se achica.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 21,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: on,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: on.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
