import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets/category_art.dart';
import '../widgets/how_to_play_demo.dart';
import '../widgets/play_background.dart';
import '../widgets/step_card.dart';

/// Qué se adivina en cada categoría y las palabras del ejemplo animado.
class _Guide {
  const _Guide(this.item, this.items, this.rounds);

  /// Lo que describe el grupo, en singular ("el animal").
  final String item;

  /// Lo mismo en plural, para "todos los que pueda" ("los animales").
  final String items;
  final List<DemoRound> rounds;
}

const _guides = {
  GameCategory.animals: _Guide('el animal', 'todos los animales', [
    ('PERRO', ['¡Ladra!', '¡Mueve la cola!', '¡Mejor amigo!'], '¿Perro?'),
    ('LEÓN', ['¡Ruge!', '¡Tiene melena!', '¡Rey de la selva!'], '¿León?'),
    ('PATO', ['¡Hace cuac!', '¡Nada en el lago!', '¡Tiene pico!'], '¿Pato?'),
  ]),
  GameCategory.geography: _Guide('el lugar', 'todos los lugares', [
    (
      'PARÍS',
      ['¡Torre Eiffel!', '¡Está en Francia!', '¡Ciudad del amor!'],
      '¿París?',
    ),
    ('NILO', ['¡Es un río!', '¡Está en Egipto!', '¡Es larguísimo!'], '¿Nilo?'),
    ('CUBA', ['¡Es una isla!', '¡En el Caribe!', '¡La Habana!'], '¿Cuba?'),
  ]),
  GameCategory.movies: _Guide('la película', 'todas las películas', [
    (
      'SHREK',
      ['¡Ogro verde!', '¡Tiene un burro!', '¡Vive en un pantano!'],
      '¿Shrek?',
    ),
    ('COCO', ['¡Día de muertos!', '¡Toca guitarra!', '¡Recuérdame!'], '¿Coco?'),
    ('TITANIC', ['¡Un barco!', '¡Se hunde!', '¡Rose y Jack!'], '¿Titanic?'),
  ]),
  GameCategory.celebrities: _Guide('la persona famosa', 'todos los famosos', [
    (
      'SHAKIRA',
      ['¡Es colombiana!', '¡Canta!', '¡Mueve las caderas!'],
      '¿Shakira?',
    ),
    ('MESSI', ['¡Futbolista!', '¡Argentino!', '¡El 10!'], '¿Messi?'),
    (
      'EINSTEIN',
      ['¡Científico!', '¡Pelo loco!', '¡Relatividad!'],
      '¿Einstein?',
    ),
  ]),
  GameCategory.brands: _Guide('la marca', 'todas las marcas', [
    ('NIKE', ['¡Ropa deportiva!', '¡Tiene un chulito!', '¡Tenis!'], '¿Nike?'),
    ('LEGO', ['¡Es un juguete!', '¡Bloques!', '¡Se arma!'], '¿Lego?'),
    ('NETFLIX', ['¡Series!', '¡Películas!', '¡Letra roja!'], '¿Netflix?'),
  ]),
  GameCategory.sports: _Guide('el deporte', 'todos los deportes', [
    ('TENIS', ['¡Raqueta!', '¡Pelota amarilla!', '¡Hay una red!'], '¿Tenis?'),
    ('BOXEO', ['¡Guantes!', '¡Un ring!', '¡Golpes!'], '¿Boxeo?'),
    ('NATACIÓN', ['¡Piscina!', '¡Gorro!', '¡Brazadas!'], '¿Natación?'),
  ]),
  GameCategory.soccerTeams: _Guide('el equipo', 'todos los equipos', [
    (
      'JUNIOR',
      ['¡De Barranquilla!', '¡Rojiblanco!', '¡El Tiburón!'],
      '¿Junior?',
    ),
    ('BARCELONA', ['¡De España!', '¡Azulgrana!', '¡Camp Nou!'], '¿Barcelona?'),
    ('MILLONARIOS', ['¡De Bogotá!', '¡Azul!', '¡Embajador!'], '¿Millonarios?'),
  ]),
};

/// "¿Cómo se juega?" de una categoría distinta de Libre: la explicación y
/// el ejemplo animado con palabras de la categoría, y el botón para ir a la
/// configuración.
class CategoryIntroScreen extends ConsumerWidget {
  const CategoryIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(gameControllerProvider).config;
    final category = config.category;
    final custom = config.customCategory;
    // Una categoría propia usa el ejemplo general (Pizza, Jirafa…).
    final guide = custom != null
        ? const _Guide('la palabra', 'todas las palabras', [])
        : _guides[category] ?? _guides[GameCategory.animals]!;
    const white = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    final steps = [
      (
        Icons.smartphone,
        AppColors.purple,
        'Una persona se pone el celular en la frente.',
      ),
      (
        Icons.record_voice_over,
        AppColors.turquoise,
        'Su grupo le describe ${guide.item} sin decir el nombre.',
      ),
      (
        Icons.psychology_alt,
        AppColors.orange,
        'Intenta adivinar ${guide.items} que pueda.',
      ),
      (
        Icons.swap_vert,
        AppColors.green,
        'Abajo si acierta, arriba para pasar.',
      ),
    ];
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(config.categoryLabel),
          leading: BackButton(onPressed: () => context.go(Routes.categories)),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Center(
                child: custom != null
                    ? _CustomArt(category: custom)
                    : CategoryArt(category: category, size: 120),
              ),
              if (custom != null && custom.description.isNotEmpty)
                Text(
                  custom.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const Text(
                '¿Cómo se juega?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Una persona se pone el celular en la frente y su grupo le '
                'describe ${guide.item} sin decir el nombre. ¡Adivinen '
                '${guide.items} que puedan antes de que se acabe el tiempo!',
                textAlign: TextAlign.center,
                style: white,
              ),
              const SizedBox(height: 16),
              PlayPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 20,
                ),
                child: guide.rounds.isEmpty
                    ? const HowToPlayDemo()
                    : HowToPlayDemo(rounds: guide.rounds),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.1,
                children: [
                  for (var i = 0; i < steps.length; i++)
                    StepCard(
                      number: i + 1,
                      icon: steps[i].$1,
                      color: steps[i].$2,
                      text: steps[i].$3,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: Text('Jugar ${config.categoryLabel}'),
                onPressed: () => context.go(Routes.config),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dibujo de una categoría propia: su ícono en un círculo de su color.
class _CustomArt extends StatelessWidget {
  const _CustomArt({required this.category});

  final CustomCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: category.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
      ),
      child: Icon(category.icon, size: 64, color: Colors.white),
    );
  }
}
