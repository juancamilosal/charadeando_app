import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme.dart';
import '../widgets/category_ticker.dart';
import '../widgets/play_background.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const _steps = [
    (Icons.groups, AppColors.blue, 'Formen grupos y escriban palabras.'),
    (Icons.face, AppColors.orange, 'Uno se pone el celular en la frente.'),
    (
      Icons.record_voice_over,
      AppColors.magenta,
      'Su grupo le da pistas sin decir la palabra.',
    ),
    (Icons.swap_vert, AppColors.green, 'Abajo si acierta, arriba para pasar.'),
    (Icons.videocam, AppColors.coral, 'La cámara graba las risas.'),
  ];

  /// Hace "respirar" el título.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                ScaleTransition(
                  scale: Tween(begin: 0.96, end: 1.04).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                  ),
                  child: const Text(
                    'Charadeando',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                const Text(
                  'El juego de charadas que graba tus risas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: PlayPanel(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          for (final (icon, color, text) in _steps)
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                child: Icon(icon),
                              ),
                              title: Text(
                                text,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const CategoryTicker(),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go(Routes.categories),
                  child: const Text('Listo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
