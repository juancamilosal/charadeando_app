import 'package:flutter/material.dart';

import '../theme.dart';

/// Recuerda que con más rondas o más tiempo conviene escribir más palabras.
class WordsReminder extends StatelessWidget {
  const WordsReminder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6D6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb, color: AppColors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Recuerda: mientras más rondas o más tiempo por turno, es '
              'recomendable escribir más palabras para que no se acaben '
              'antes de tiempo. El juego termina cuando se completan todas '
              'las rondas o cuando se acaban las palabras.',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
