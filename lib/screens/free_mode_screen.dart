import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/how_to_play_demo.dart';
import '../widgets/play_background.dart';

/// Presentación de la categoría Libre: cómo se juega y de dónde salen las
/// palabras.
class FreeModeScreen extends ConsumerWidget {
  const FreeModeScreen({super.key});

  static const _steps = [
    (
      Icons.smartphone,
      AppColors.purple,
      'Una persona se pone el celular en la frente.',
    ),
    (
      Icons.record_voice_over,
      AppColors.turquoise,
      'Su grupo ve la palabra y la describe sin decirla.',
    ),
    (
      Icons.psychology_alt,
      AppColors.orange,
      'Intenta adivinar todas las que pueda.',
    ),
    (Icons.swap_vert, AppColors.green, 'Abajo si acierta, arriba para pasar.'),
  ];

  void _manual(BuildContext context, WidgetRef ref) {
    ref
        .read(gameControllerProvider.notifier)
        .configure(
          ref
              .read(gameControllerProvider)
              .config
              .copyWith(wordSource: WordSource.groups),
        );
    context.go(Routes.config);
  }

  void _automatic(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Muy pronto pondremos las palabras por ustedes.'),
        ),
      );
  }

  /// Llena la partida con valores de prueba y va directo al primer turno.
  void _testValues(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    controller.configure(TestData.config);
    final words = TestData.words();
    for (var i = 0; i < words.length; i++) {
      controller.setWrittenWords(i, words[i]);
    }
    controller.start();
    context.go(Routes.turn);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const white = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Libre'),
          leading: BackButton(onPressed: () => context.go(Routes.categories)),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const Text(
                '¿Cómo se juega?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Una persona se pone el celular en la frente y su grupo le '
                'describe la palabra sin decirla. ¡Adivinen todas las que '
                'puedan antes de que se acabe el tiempo!',
                textAlign: TextAlign.center,
                style: white,
              ),
              const SizedBox(height: 16),
              const PlayPanel(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                child: HowToPlayDemo(),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.1,
                children: [
                  for (var i = 0; i < _steps.length; i++)
                    _StepCard(
                      number: i + 1,
                      icon: _steps[i].$1,
                      color: _steps[i].$2,
                      text: _steps[i].$3,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Elige el tipo de juego',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Text(
                '¿De dónde saldrán las palabras de la partida?',
                textAlign: TextAlign.center,
                style: white,
              ),
              const SizedBox(height: 14),
              _ModeCard(
                icon: Icons.edit_note,
                color: AppColors.purple,
                title: 'Palabras manuales',
                description:
                    'Ustedes escriben sus propias palabras antes de empezar. '
                    '¡Perfecto para bromas internas y palabras de la familia!',
                suggestion:
                    'Entre más rondas y más tiempo por turno, más palabras '
                    'se juegan. Ustedes eligen cuántas escribir en la '
                    'configuración.',
                onTap: () => _manual(context, ref),
              ),
              const SizedBox(height: 12),
              _ModeCard(
                icon: Icons.auto_awesome,
                color: AppColors.turquoise,
                title: 'Palabras automáticas',
                description:
                    'Nosotros ponemos las palabras por ustedes. Solo denle '
                    'comenzar y a jugar sin pensar en nada más.',
                comingSoon: true,
                onTap: () => _automatic(context),
              ),
              if (TestData.enabled) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  icon: const Icon(Icons.science),
                  label: const Text('Ingresar valores de prueba'),
                  onPressed: () => _testValues(context, ref),
                ),
                const SizedBox(height: 4),
                const Text(
                  '2 grupos, 2 rondas de 30 s y 10 palabras por grupo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.icon,
    required this.color,
    required this.text,
  });

  final int number;
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$number. ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: text),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
    this.suggestion,
    this.comingSoon = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String? suggestion;
  final bool comingSoon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(icon, size: 44, color: color),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              if (suggestion != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6D6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lightbulb,
                        size: 20,
                        color: AppColors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          suggestion!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: comingSoon
                      ? const Color(0xFFEDE7F6)
                      : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      comingSoon ? Icons.lock_clock : Icons.circle,
                      size: comingSoon ? 14 : 8,
                      color: comingSoon ? AppColors.ink : color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      comingSoon ? 'PRONTO' : 'ELEGIR',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                        color: comingSoon ? AppColors.ink : color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
