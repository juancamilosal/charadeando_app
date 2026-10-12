import 'package:flutter/material.dart';

import '../theme.dart';

/// Recuerda que con más rondas o más tiempo conviene escribir más palabras.
class WordsReminder extends StatelessWidget {
  const WordsReminder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6D6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.lightbulb, color: AppColors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Más rondas = más palabras',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
