import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets/category_art.dart';
import '../widgets/punishment_roulette.dart';

/// Una pantalla de "Cómo se juega": título, texto corto, la imagen (las
/// categorías, la ruleta o una ilustración) y el texto del botón.
typedef _Page = (String title, String text, Widget art, String button);

/// "Cómo se juega": seis pantallas que se pasan con "Continuar" o
/// deslizando. Se ven la primera vez que se abre la app y desde Ajustes >
/// Ayuda. "Omitir" las salta.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  /// Fondo de las pantallas, el de las ilustraciones.
  static const gradient = [Color(0xFF2B3BF0), Color(0xFF5A12F0)];

  /// Categorías de ejemplo de la primera pantalla.
  static const sampleCategories = [
    GameCategory.animals,
    GameCategory.movies,
    GameCategory.geography,
    GameCategory.celebrities,
    GameCategory.brands,
    GameCategory.free,
  ];

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
        'Elige una categoría',
        'Selecciona la categoría que deseas jugar.',
        const _CategoryGrid(),
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
        'Castiga al equipo que pierda',
        'Al final, el equipo con menos puntos gira la ruleta de castigos.',
        const _SampleRoulette(),
        'Continuar',
      ),
      (
        '¡Listos para divertirse!',
        'Con sus amigos y su familia.',
        const _Art('assets/img/inicio/abrazados.webp'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
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
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: art),
        ],
      ),
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

/// Primera pantalla: algunas categorías que se pueden jugar.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // Tres filas de dos, del tamaño que quepa.
        final width = (box.maxWidth - 14) / 2;
        final height = (box.maxHeight - 28) / 3;
        return GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: width / height,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final c in WelcomeScreen.sampleCategories) _CategoryTile(c),
          ],
        );
      },
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
            child: CategoryArt.restFrames.containsKey(category)
                ? Image.asset(
                    CategoryArt.restAsset(category),
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
