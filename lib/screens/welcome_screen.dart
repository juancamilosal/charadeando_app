import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _steps = [
    (Icons.groups, 'Formen grupos y escriban palabras para sus rivales.'),
    (Icons.face, 'Un jugador se pone el celular en la frente.'),
    (Icons.record_voice_over, 'Su grupo le da pistas sin decir la palabra.'),
    (
      Icons.arrow_downward,
      'Inclina hacia abajo si acierta, hacia arriba para pasar.',
    ),
    (Icons.videocam, 'La cámara graba las risas de cada turno.'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Text(
                'Charadeando',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'El juego de charadas que graba tus risas.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    for (final (icon, text) in _steps)
                      ListTile(leading: Icon(icon), title: Text(text)),
                  ],
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Jugar'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  textStyle: theme.textTheme.titleLarge,
                ),
                onPressed: () => context.go(Routes.config),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
