import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets/category_art.dart';
import '../widgets/punishment_roulette.dart';
import '../widgets/team_badge.dart';

/// Una pantalla de "Cómo se juega": título, texto corto, la imagen (las
/// categorías, la ruleta o una ilustración) y el texto del botón.
typedef _Page = (String title, String text, Widget art, String button);

/// "Cómo se juega": ocho pantallas que se pasan con "Continuar" o
/// deslizando. Se ven la primera vez que se abre la app y desde Ajustes >
/// Ayuda. "Omitir" las salta.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  /// Fondo de las pantallas, el de las ilustraciones.
  static const gradient = [Color(0xFF2B3BF0), Color(0xFF5A12F0)];

  /// Categorías de la primera pantalla, en dos filas que se mueven: las
  /// que ya se pueden jugar (sin las de "Pronto" ni las especiales fuera
  /// de temporada).
  static List<List<GameCategory>> get carouselRows {
    final today = DateTime.now();
    final all = [
      for (final c in GameCategory.themed)
        if (c.available && c.shownOn(today)) c,
      GameCategory.free,
    ];
    final half = (all.length / 2).ceil();
    return [all.sublist(0, half), all.sublist(half)];
  }

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _pager = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  /// Los textos dicen cómo se marca según el controlador de Ajustes.
  List<_Page> _pages(PlayController controller) {
    final touch = controller == PlayController.touch;
    return [
      (
        'Muchas categorías para jugar',
        'Animales, películas, deportes… y puedes crear las tuyas.',
        const _CategoryCarousel(),
        'Continuar',
      ),
      (
        'Cómo empezar',
        'Ponte el celular en la frente. Tu equipo actúa o da pistas para '
            'que adivines la palabra.',
        const _Art('assets/img/inicio/jugando.webp'),
        'Continuar',
      ),
      (
        '¿Lo has acertado?',
        touch
            ? 'Toca la derecha de la pantalla y suma un punto.'
            : 'Inclina el celular hacia abajo y suma un punto.',
        const _Art('assets/img/inicio/acierto.webp'),
        'Continuar',
      ),
      (
        '¿No puedes adivinar?',
        touch
            ? 'Toca la izquierda de la pantalla y pasa a la siguiente '
                  'palabra.'
            : 'Inclina el celular hacia arriba y pasa a la siguiente '
                  'palabra.',
        const _Art('assets/img/inicio/pasar.webp'),
        'Continuar',
      ),
      (
        'Jueguen por equipos',
        'Cada equipo tiene su turno. Suman puntos y gana el que más acierte.',
        const _SampleTeams(),
        'Continuar',
      ),
      (
        'Castiga al equipo que pierda',
        'Al final, el equipo con menos puntos gira la ruleta de castigos.',
        const _SampleRoulette(),
        'Continuar',
      ),
      (
        'Modo TV',
        'Conecta el celular a un TV. Quien adivina se pone de espaldas y '
            'un juez marca con los botones.',
        const _Art('assets/img/inicio/tv.webp'),
        'Continuar',
      ),
      (
        '¡Listos para divertirse!',
        'Con sus amigos y su familia.',
        const _Art('assets/img/inicio/final.webp'),
        '¡Vamos a jugar!',
      ),
    ];
  }

  /// La primera vez queda guardado que ya se vio y se va a Categorías; si
  /// se abrió desde Ajustes, se regresa.
  void _done() {
    ref.read(welcomeSeenProvider.notifier).markSeen();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.categories);
    }
  }

  void _next(int count) {
    if (_page >= count - 1) {
      _done();
      return;
    }
    _pager.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages(ref.watch(settingsProvider).controller);
    final last = _page == pages.length - 1;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: WelcomeScreen.gradient,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // "Omitir" arriba a la derecha, menos en la última.
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: last
                      ? null
                      : TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withValues(
                              alpha: 0.7,
                            ),
                            textStyle: const TextStyle(
                              fontFamily: AppFonts.display,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _done,
                          child: const Text('Omitir'),
                        ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pager,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [for (final p in pages) _PageView(page: p)],
                ),
              ),
              const SizedBox(height: 12),
              _Dots(count: pages.length, index: _page),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
                child: _GreenButton(
                  label: pages[_page].$4,
                  onPressed: () => _next(pages.length),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    final (title, text, art, _) = page;
    const side = EdgeInsets.symmetric(horizontal: 24);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: side,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 38,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: side,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // El carrusel va de borde a borde; lo demás, con margen.
        Expanded(
          child: art is _CategoryCarousel
              ? art
              : Padding(padding: side, child: art),
        ),
      ],
    );
  }
}

/// Una ilustración, del tamaño que quepa.
class _Art extends StatelessWidget {
  const _Art(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) => Image.asset(asset, fit: BoxFit.contain);
}

/// Una tabla de puntos de ejemplo, con tres equipos.
class _SampleTeams extends StatelessWidget {
  const _SampleTeams();

  static const _teams = [
    (SavedTeam(id: 'a', name: 'Los Primos', colorIndex: 0, emoji: '🦁'), 7),
    (SavedTeam(id: 'b', name: 'Las Tías', colorIndex: 1, emoji: '🦄'), 5),
    (SavedTeam(id: 'c', name: 'Los Abuelos', colorIndex: 5, emoji: '🐢'), 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, (team, points)) in _teams.indexed)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: i == 0
                      ? Border.all(color: AppColors.yellow, width: 3)
                      : null,
                ),
                child: Row(
                  children: [
                    TeamBadge(team: team, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        team.name,
                        style: const TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (i == 0) ...[
                      const Icon(Icons.emoji_events, color: AppColors.orange),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      '$points',
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.purple,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// La ruleta de castigos con algunos castigos de ejemplo, quieta.
class _SampleRoulette extends StatelessWidget {
  const _SampleRoulette();

  static const punishments = [
    'Bailar 10 segundos',
    'Imitar a un animal',
    'Cantar el coro',
    'Hablar como robot',
    'Contar un chiste',
    'Hacer 5 sentadillas',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: RoulettePainter(punishments: punishments, angle: 0.3),
        ),
      ),
    );
  }
}

/// Primera pantalla: las categorías pasan en dos filas, de derecha a
/// izquierda, como una vitrina. Es solo informativa: no se pueden tocar.
class _CategoryCarousel extends StatelessWidget {
  const _CategoryCarousel();

  @override
  Widget build(BuildContext context) {
    final rows = WelcomeScreen.carouselRows;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          // Dos filas (cada una con 6 px de sombra) y 18 px entre ellas.
          final height = ((box.maxHeight - 30) / 2).clamp(0.0, 170.0);
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MarqueeRow(
                categories: rows[0],
                height: height,
                period: const Duration(seconds: 22),
              ),
              const SizedBox(height: 18),
              _MarqueeRow(
                categories: rows[1],
                height: height,
                period: const Duration(seconds: 28),
                // Empieza corrida, para que no queden alineadas.
                start: 0.4,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Una fila de tarjetas que se mueve sin parar hacia la izquierda.
class _MarqueeRow extends StatefulWidget {
  const _MarqueeRow({
    required this.categories,
    required this.height,
    required this.period,
    this.start = 0,
  });

  final List<GameCategory> categories;
  final double height;

  /// Lo que tarda en pasar la fila completa.
  final Duration period;

  /// Dónde empieza, de 0 a 1.
  final double start;

  @override
  State<_MarqueeRow> createState() => _MarqueeRowState();
}

class _MarqueeRowState extends State<_MarqueeRow>
    with SingleTickerProviderStateMixin {
  static const _gap = 14.0;

  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: widget.period,
    value: widget.start,
  )..repeat();

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = widget.height * 0.82;
    final strip = widget.categories.length * (cardWidth + _gap);
    final cards = [
      for (final c in widget.categories)
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
            width: cardWidth,
            height: widget.height,
            child: _CategoryTile(c),
          ),
        ),
    ];
    return SizedBox(
      height: widget.height + 6,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: 0,
          maxWidth: double.infinity,
          child: AnimatedBuilder(
            animation: _move,
            builder: (context, child) => Transform.translate(
              offset: Offset(-_move.value * strip, 0),
              child: child,
            ),
            // Dos veces la fila: cuando la primera sale, la segunda ya
            // ocupa su lugar.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [...cards, ...cards],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile(this.category);

  final GameCategory category;

  @override
  Widget build(BuildContext context) {
    final onColor = category.color == AppColors.yellow
        ? AppColors.ink
        : Colors.white;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: category.color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: CategoryArt.withImage.contains(category)
                ? Image.asset(
                    CategoryArt.asset(category),
                    errorBuilder: (_, _, _) =>
                        Icon(category.icon, color: onColor, size: 48),
                  )
                : Icon(category.icon, color: onColor, size: 48),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              category.label,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: onColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Puntos que dicen en qué pantalla se está.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: i == index ? 1 : 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

/// Botón verde grande: "Continuar" o "¡Vamos a jugar!".
class _GreenButton extends StatelessWidget {
  const _GreenButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(32),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shadowColor: const Color(0x66000000),
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5BD86B), Color(0xFF3CB64C)],
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 62,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [Shadow(color: Color(0x40000000), blurRadius: 4)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
