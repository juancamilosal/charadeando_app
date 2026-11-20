import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

/// ¿Más o menos? en el turno: arriba el tema del dato, en el centro la
/// pregunta y abajo, muy grande, la respuesta con su unidad ("8 patas").
/// Se lee de lejos: lo ve el grupo, que grita "¡más!" o "¡menos!".
class FactView extends StatelessWidget {
  const FactView({super.key, required this.word, this.scale = 1});

  final Word word;

  /// Para el televisor, un poco más pequeño que en el celular.
  final double scale;

  static const _shadow = [
    Shadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
  ];

  @override
  Widget build(BuildContext context) {
    // Arriba, el tema y cuánto vale: "ANIMALES · 1 PUNTO".
    final value = word.value;
    final topic = [
      ?word.topic?.toUpperCase(),
      if (value != null) value == 1 ? '1 PUNTO' : '$value PUNTOS',
    ].join(' · ');
    return Column(
      children: [
        if (topic.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              topic,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18 * scale,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
        Expanded(
          flex: 5,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                // La pregunta en dos o tres líneas, no en una larguísima.
                constraints: BoxConstraints(maxWidth: 760 * scale),
                child: Text(
                  word.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 44 * scale,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    shadows: _shadow,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  word.answer ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 110 * scale,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
