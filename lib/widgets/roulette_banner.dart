import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'punishment_roulette.dart';

/// Botón de la sección "Ruleta de castigos": una ruleta pequeña que gira
/// despacio y el nombre de la sección.
class RouletteBanner extends StatefulWidget {
  const RouletteBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<RouletteBanner> createState() => _RouletteBannerState();
}

class _RouletteBannerState extends State<RouletteBanner>
    with SingleTickerProviderStateMixin {
  static const _fields = ['', '', '', '', '', '', '', ''];

  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 92,
                child: AnimatedBuilder(
                  animation: _turn,
                  builder: (_, _) => CustomPaint(
                    painter: RoulettePainter(
                      punishments: _fields,
                      angle: _turn.value * 2 * pi,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ruleta de castigos',
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Para el grupo que pierde',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B5A86),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: AppColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}
