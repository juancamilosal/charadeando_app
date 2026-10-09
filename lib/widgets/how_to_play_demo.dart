import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Animación de cómo se juega: una persona tiene el celular en la frente,
/// su grupo le describe la palabra secreta sin decirla y, cuando acierta,
/// inclina el celular y sale la siguiente palabra.
class HowToPlayDemo extends StatefulWidget {
  const HowToPlayDemo({super.key});

  @override
  State<HowToPlayDemo> createState() => _HowToPlayDemoState();
}

class _HowToPlayDemoState extends State<HowToPlayDemo>
    with SingleTickerProviderStateMixin {
  /// Palabras del ejemplo, con tres pistas y el intento de quien adivina.
  static const _rounds = [
    ('PIZZA', ['¡Es redonda!', '¡Tiene queso!', '¡Es italiana!'], '¿Pizza?'),
    ('GATO', ['¡Dice miau!', '¡Tiene bigotes!', '¡Es mascota!'], '¿Gato?'),
    ('FÚTBOL', ['¡Hay un balón!', '¡Once jugadores!', '¡Goool!'], '¿Fútbol?'),
  ];
  static const _people = [
    AppColors.purple,
    AppColors.turquoise,
    AppColors.blue,
    AppColors.orange,
  ];

  /// La misma persona adivina durante todo el turno.
  static const _guesser = 3;

  /// Pasos de cada palabra: tres pistas, el intento y el acierto.
  static const _steps = 5;

  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  late final Timer _timer;
  int _step = 0;
  int _round = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      setState(() {
        _step = (_step + 1) % _steps;
        // Después del acierto sale la siguiente palabra.
        if (_step == 0) _round = (_round + 1) % _rounds.length;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _wave.dispose();
    super.dispose();
  }

  String get _word => _rounds[_round].$1;

  bool get _correct => _step == _steps - 1;

  /// Quién habla en este paso: una persona del grupo, o quien adivina.
  int get _speaker => _step >= 3 ? _guesser : _step;

  String get _bubble => switch (_step) {
    3 => _rounds[_round].$3,
    4 => '¡Correcto!',
    _ => _rounds[_round].$2[_step],
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'PALABRA SECRETA',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _wave,
          builder: (context, _) => FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (var i = 0; i < _word.length; i++) _tile(i)],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // En pantallas angostas la fila se encoge en vez de desbordarse.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < _people.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _person(i),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert, size: 18, color: AppColors.purple),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Inclina el celular hacia abajo si aciertas y hacia arriba '
                'para pasar.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tile(int i) {
    // Las letras saltan como una ola; al acertar, saltan todas juntas.
    final phase = (_wave.value * 2 * pi) - i * 0.7;
    final lift = _correct ? 8.0 : max(0.0, sin(phase)) * 8;
    return Transform.translate(
      offset: Offset(0, -lift),
      child: Transform.rotate(
        angle: (i.isEven ? -1 : 1) * 0.08,
        child: Container(
          width: 40,
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _correct
                  ? const [AppColors.green, Color(0xFF0E9F55)]
                  : const [AppColors.purple, AppColors.blue],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            _word[i],
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _person(int i) {
    final guessing = i == _guesser;
    final speaking = i == _speaker;
    return SizedBox(
      width: 66,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 34,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: speaking
                  // El globo puede ser más ancho que la columna de la
                  // persona, para que el texto quepa completo.
                  ? OverflowBox(
                      key: ValueKey('$_round-$_step'),
                      maxWidth: _Bubble.maxWidth,
                      child: _Bubble(
                        text: _bubble,
                        color: _correct ? AppColors.green : Colors.white,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 4),
          // Al acertar, quien adivina inclina el celular hacia abajo.
          AnimatedRotation(
            turns: guessing && _correct ? 0.06 : 0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              width: guessing ? 56 : 48,
              height: guessing ? 56 : 48,
              decoration: BoxDecoration(
                color: _people[i],
                shape: BoxShape.circle,
                border: Border.all(
                  color: guessing ? AppColors.yellow : Colors.white,
                  width: 3,
                ),
              ),
              child: Icon(
                guessing ? Icons.smartphone : Icons.record_voice_over,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            guessing ? 'Adivina' : 'Describe',
            style: TextStyle(
              fontSize: 12,
              fontWeight: guessing ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.color});

  static const maxWidth = 120.0;

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final light = color == Colors.white;
    return Container(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: light ? Border.all(color: const Color(0xFFE2D8F5)) : null,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      // Si el texto no cabe en el ancho máximo, se achica dentro del globo.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: light ? AppColors.ink : Colors.white,
          ),
        ),
      ),
    );
  }
}
