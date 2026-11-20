import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'category_art.dart';

/// Fondo del cartel de ¿Más o menos? en Categorías.
const moreOrLessBackground = Color(0xFF0D2B36);

/// ¿Más o menos? en "Más juegos": un cartel ancho y oscuro, como el de
/// Fotomímica, con su nombre, qué es, un dato de ejemplo y "Jugar".
class MoreOrLessSection extends StatelessWidget {
  const MoreOrLessSection({super.key, required this.onPlay});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: moreOrLessBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Colors.white, width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPlay,
        child: SizedBox(
          height: 190,
          child: Stack(
            children: [
              // Un dato de ejemplo, con lo que grita el grupo.
              const Positioned(right: 10, top: 18, child: _SampleFact()),
              const Positioned(
                right: 104,
                top: 120,
                child: _Shout('¡Más!', AppColors.green, angle: -0.1),
              ),
              const Positioned(
                right: 12,
                top: 132,
                child: _Shout('¡Menos!', AppColors.coral, angle: 0.08),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 160, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CategoryArt(
                          category: GameCategory.moreOrLess,
                          size: 26,
                          color: AppColors.turquoise,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.yellow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'NUEVO JUEGO',
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '¿Más o menos?',
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 30,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Expanded(
                      child: Text(
                        'Di números hasta dar con el exacto. Los demás te '
                        'guían: ¡más! o ¡menos!',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.turquoise,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(width: 2),
                            Text(
                              'Jugar',
                              style: TextStyle(
                                fontFamily: AppFonts.display,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
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

/// Tarjeta de ejemplo: una pregunta y su respuesta.
class _SampleFact extends StatelessWidget {
  const _SampleFact();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.05,
      child: Container(
        width: 140,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.word),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              '¿Cuántas patas tiene una araña?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 13,
                height: 1.1,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '8 patas',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "¡Más!" o "¡Menos!", como un grito del grupo.
class _Shout extends StatelessWidget {
  const _Shout(this.text, this.color, {required this.angle});

  final String text;
  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
