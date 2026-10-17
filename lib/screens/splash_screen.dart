import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../router.dart';
import '../theme.dart';

/// Un destello de la pantalla de carga: dónde va (centro, en fracción del
/// ancho y del alto), qué tan grande (fracción del ancho), su color (null es
/// el lila del dibujo) y cómo titila (cada cuánto y con qué retraso).
class Sparkle {
  const Sparkle(
    this.x,
    this.y,
    this.size, {
    this.tint,
    this.period = 2.0,
    this.delay = 0,
  });

  final double x;
  final double y;
  final double size;
  final Color? tint;

  /// Segundos de un titileo completo.
  final double period;

  /// Segundos de retraso, para que no titilen todos a la vez.
  final double delay;

  /// Cuánto brilla en [seconds]: de 0 (apagado) a 1 (encendido), suave.
  double glowAt(double seconds) {
    final phase = ((seconds + delay) / period) % 1;
    return 0.5 - 0.5 * cos(2 * pi * phase);
  }
}

/// Pantalla de carga: la primera ruta de la app. Fondo morado con un brillo
/// detrás del logo, el logo que entra con un pequeño rebote, destellos que
/// titilan y "by ValkiriaCode" abajo. A los [duration] (o al tocarla) pasa
/// con un fundido a Categorías, o a la bienvenida la primera vez. Va justo
/// después del splash nativo de Android, con el mismo fondo, para que el
/// paso no se note.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 1800),
  });

  final Duration duration;

  static const background = Color(0xFF1F0252);
  static const glow = Color(0xFF6E28E6);
  static const yellow = Color(0xFFFFD23F);
  static const turquoise = Color(0xFF1FC8B4);
  static const magenta = Color(0xFFE5197E);

  static const logoAsset = 'assets/img/marca/splash_logo.webp';
  static const sparkleAsset = 'assets/img/marca/destello.webp';

  /// Ancho del logo, en fracción del ancho de la pantalla.
  static const logoWidth = 0.72;

  /// Alto del centro del logo, en fracción del alto de la pantalla.
  static const logoCenter = 0.47;

  /// Proporción del logo (ancho / alto).
  static const logoAspect = 1000 / 620;

  /// Los destellos, repartidos como en la referencia: lejos del logo (que
  /// además va encima) y de la firma. La mayoría lilas y 6 teñidos.
  static const sparkles = [
    Sparkle(0.35, 0.07, 0.09, period: 2.2, delay: 0.3),
    Sparkle(0.52, 0.13, 0.10, period: 1.8, delay: 1.1),
    Sparkle(0.82, 0.12, 0.16, tint: turquoise, period: 2.6, delay: 0.6),
    Sparkle(0.59, 0.20, 0.20, tint: yellow, period: 2.0, delay: 1.5),
    Sparkle(0.82, 0.20, 0.18, period: 2.8, delay: 0.2),
    Sparkle(0.21, 0.245, 0.30, period: 3.0, delay: 0.9),
    Sparkle(0.65, 0.29, 0.08, period: 1.6, delay: 0.4),
    Sparkle(0.89, 0.36, 0.15, period: 2.4, delay: 1.3),
    Sparkle(0.11, 0.43, 0.12, period: 2.1, delay: 0.7),
    Sparkle(0.90, 0.50, 0.16, tint: magenta, period: 2.5, delay: 0.1),
    Sparkle(0.10, 0.55, 0.17, tint: turquoise, period: 2.3, delay: 1.7),
    Sparkle(0.91, 0.59, 0.09, period: 1.9, delay: 0.5),
    Sparkle(0.67, 0.615, 0.08, period: 1.7, delay: 1.2),
    Sparkle(0.16, 0.65, 0.17, period: 2.7, delay: 0.8),
    Sparkle(0.56, 0.73, 0.18, tint: yellow, period: 2.2, delay: 1.9),
    Sparkle(0.76, 0.73, 0.26, period: 2.9, delay: 0.3),
    Sparkle(0.24, 0.78, 0.13, tint: magenta, period: 2.0, delay: 1.4),
    Sparkle(0.44, 0.81, 0.09, period: 1.8, delay: 0.6),
    Sparkle(0.07, 0.83, 0.08, period: 2.4, delay: 1.0),
    Sparkle(0.93, 0.885, 0.10, period: 2.1, delay: 0.2),
  ];

  /// Las imágenes de la pantalla, para cargarlas antes de mostrarla.
  static Future<void> precache(BuildContext context) => Future.wait([
    precacheImage(const AssetImage(logoAsset), context),
    precacheImage(const AssetImage(sparkleAsset), context),
  ]);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  /// Entrada del logo: escala de 0.85 a 1 con un leve rebote y opacidad.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  /// Tiempo desde que se ve la pantalla, para el titileo.
  final _elapsed = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (elapsed) => _elapsed.value = elapsed.inMicroseconds / 1e6,
  );

  Timer? _timer;
  bool _ready = false;
  bool _leaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready || _timer != null) return;
    // Primero las imágenes, para que no aparezcan de golpe; después la
    // animación y la cuenta para seguir.
    _timer = Timer(widget.duration, _leave);
    SplashScreen.precache(context).whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      _intro.forward();
      if (!_still) _ticker.start();
    });
  }

  /// "Reducir animaciones" activado: el logo aparece sin rebote y los
  /// destellos quedan quietos.
  bool get _still => MediaQuery.disableAnimationsOf(context);

  void _leave() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
    final welcomeSeen = ref.read(welcomeSeenProvider);
    // Las dos entran con un fundido (ver el router).
    context.go(welcomeSeen ? Routes.categories : Routes.welcome);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ticker.dispose();
    _intro.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = _still;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Al tocar, pasa de una vez.
      onTap: _leave,
      child: ColoredBox(
        color: SplashScreen.background,
        child: LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            final height = box.maxHeight;
            final logoWidth = width * SplashScreen.logoWidth;
            final logoHeight = logoWidth / SplashScreen.logoAspect;
            final logoTop = height * SplashScreen.logoCenter - logoHeight / 2;
            return Stack(
              children: [
                // Brillo suave detrás del logo.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, SplashScreen.logoCenter * 2 - 1),
                        radius: 0.75,
                        colors: [
                          SplashScreen.glow.withValues(alpha: 0.55),
                          SplashScreen.glow.withValues(alpha: 0.18),
                          SplashScreen.glow.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
                if (_ready)
                  for (final sparkle in SplashScreen.sparkles)
                    _SparkleView(
                      sparkle: sparkle,
                      area: Size(width, height),
                      elapsed: still ? null : _elapsed,
                    ),
                if (_ready)
                  Positioned(
                    left: (width - logoWidth) / 2,
                    top: logoTop,
                    width: logoWidth,
                    height: logoHeight,
                    child: AnimatedBuilder(
                      animation: _intro,
                      builder: (context, child) {
                        final t = _intro.value;
                        final scale = still
                            ? 1.0
                            : 0.85 + 0.15 * Curves.easeOutBack.transform(t);
                        return Opacity(
                          opacity: Curves.easeOut.transform(t),
                          child: Transform.scale(scale: scale, child: child),
                        );
                      },
                      child: Image.asset(
                        SplashScreen.logoAsset,
                        fit: BoxFit.contain,
                        semanticLabel: 'Charadeando',
                      ),
                    ),
                  ),
                // La firma, abajo y dentro del área segura.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        'by ValkiriaCode',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.body,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.7),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Tiñe el destello lila de [tint]: toma su brillo (el centro claro y los
/// rayos más oscuros) y lo pinta de ese color, con un poco de blanco en el
/// centro. Lo transparente sigue transparente.
ColorFilter tinted(Color tint) {
  // De cada canal del color, cuánto toma del brillo del destello.
  List<double> row(double c) {
    final k = (0.78 * c + 0.22) * 1.15;
    return [0.299 * k, 0.587 * k, 0.114 * k, 0, 0];
  }

  return ColorFilter.matrix([
    ...row(tint.r),
    ...row(tint.g),
    ...row(tint.b),
    0,
    0,
    0,
    1,
    0,
  ]);
}

/// Un destello en su lugar. Con [elapsed] titila (opacidad y un poco de
/// escala); sin él, queda quieto.
class _SparkleView extends StatelessWidget {
  const _SparkleView({
    required this.sparkle,
    required this.area,
    required this.elapsed,
  });

  final Sparkle sparkle;
  final Size area;
  final ValueListenable<double>? elapsed;

  @override
  Widget build(BuildContext context) {
    final size = area.width * sparkle.size;
    final tint = sparkle.tint;
    Widget image = Image.asset(
      SplashScreen.sparkleAsset,
      width: size,
      height: size,
    );
    if (tint != null) {
      image = ColorFiltered(colorFilter: tinted(tint), child: image);
    }
    final elapsed = this.elapsed;
    if (elapsed != null) {
      image = ValueListenableBuilder<double>(
        valueListenable: elapsed,
        child: image,
        builder: (context, seconds, child) {
          final glow = sparkle.glowAt(seconds);
          return Opacity(
            opacity: 0.45 + 0.55 * glow,
            child: Transform.scale(scale: 0.88 + 0.14 * glow, child: child),
          );
        },
      );
    } else {
      image = Opacity(opacity: 0.85, child: image);
    }
    return Positioned(
      left: area.width * sparkle.x - size / 2,
      top: area.height * sparkle.y - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(child: image),
    );
  }
}
