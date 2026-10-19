import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../router.dart';
import '../theme.dart';
import '../models/models.dart';
import '../widgets/backdrop_tile.dart';
import '../widgets/play_background.dart';
import '../widgets/punishment_roulette.dart';
import '../widgets/result_parts.dart';
import '../widgets/scoreboard.dart';
import 'roulette_screen.dart' show PunishmentSpinScreen, RouletteSetupView;

/// Ganador (o empate) con sus puntos en grande, la tabla de puntajes, la
/// ruleta de castigo (la misma de la sección Ruleta) y "Jugar otra vez" o "Cambiar configuración".
class FinalResultScreen extends ConsumerStatefulWidget {
  const FinalResultScreen({super.key});

  @override
  ConsumerState<FinalResultScreen> createState() => _FinalResultScreenState();
}

/// Cuánto se espera después de mostrar al ganador para pedir la reseña.
const reviewDelay = Duration(seconds: 2);

class _FinalResultScreenState extends ConsumerState<FinalResultScreen> {
  /// Cuántos de los grupos con menos puntos ya giraron (o saltaron) su
  /// ruleta de castigo. Giran uno después del otro.
  int _punished = 0;

  @override
  void initState() {
    super.initState();
    // Por si quedó algún video temporal de la partida.
    ref.read(videoServiceProvider).deleteAll().ignore();
    // La partida se suma al historial de los equipos guardados.
    ref.read(gameControllerProvider.notifier).saveHistory().ignore();
    // Y a las estadísticas anónimas, como terminada. Después de construir
    // la pantalla, porque cambia el estado de la partida.
    Future(() {
      if (!mounted) return;
      final controller = ref.read(gameControllerProvider.notifier)
        ..recordStats();
      _maybeAskReview(controller.hadErrors).ignore();
    });
  }

  /// "Girar" (o soltarla con impulso): la ruleta sigue girando a pantalla
  /// completa, desde donde quedó y hacia el mismo lado. Al volver, le toca
  /// al siguiente empatado, si hay.
  Future<void> _spin(
    String group,
    List<String> punishments,
    RouletteSpin spin,
  ) async {
    await context.push<bool>(
      Routes.punishmentSpin,
      extra: (group, punishments, spin),
    );
    if (mounted) setState(() => _punished++);
  }

  /// Desde la 3.ª partida terminada, con ganador y sin errores, se pide la
  /// reseña de Play Store unos segundos después de ver al ganador. Nunca
  /// encima de la ruleta: si ya la abrieron, no se pide.
  Future<void> _maybeAskReview(bool hadErrors) async {
    final game = ref.read(gameControllerProvider);
    final review = ref.read(reviewServiceProvider);
    final ask = await review.gameFinished(
      hasWinner: game.inGroups && !game.isTie,
      hadErrors: hadErrors,
    );
    if (!ask) return;
    await Future<void>.delayed(reviewDelay);
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    await review.ask();
  }

  /// Otra partida con la misma configuración: las palabras se vuelven a
  /// escribir o a pedir.
  void _playAgain() {
    final config = ref.read(gameControllerProvider).config;
    ref.read(gameControllerProvider.notifier).configure(config);
    context.go(
      config.wordSource == WordSource.random ? Routes.autoWords : Routes.words,
    );
  }

  /// A la configuración, con la de esta partida.
  void _changeConfig() {
    final config = ref.read(gameControllerProvider).config;
    ref.read(gameControllerProvider.notifier).configure(config);
    context.go(Routes.config);
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    final leaders = [for (final i in game.leaders) game.groups[i].name];
    final losers = [for (final i in game.losers) game.groups[i].name];
    // Sin grupos no hay ganador ni castigo: solo el total.
    final title = !game.inGroups
        ? '¡Fin del juego!'
        : game.isTie
        ? '¡Empate entre ${_joinNames(leaders)}!'
        : '¡Ganó ${leaders.single}!';

    final scores = game.scores;
    final best = game.inGroups ? scores[game.leaders.first] : game.totalScore;
    return PopScope(
      canPop: false,
      child: PlayBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        Icon(
                          Icons.emoji_events,
                          size: 72,
                          color: context.backdrop.light
                              ? AppColors.orange
                              : AppColors.yellow,
                          shadows: const [
                            Shadow(color: Colors.black26, blurRadius: 12),
                          ],
                        ),
                        ResultTitle(title: title),
                        const SizedBox(height: 4),
                        BigScore(
                          value: best,
                          label: best == 1 ? 'Punto' : 'Puntos',
                        ),
                        if (game.inGroups) ...[
                          const SizedBox(height: 16),
                          Scoreboard(
                            groups: game.groups,
                            scores: scores,
                            // El primero, resaltado.
                            highlight: game.isTie ? null : game.leaders.single,
                          ),
                        ],
                        // La misma ruleta de la sección, con su
                        // configuración. Cada empatado gira la suya.
                        if (_punished < losers.length) ...[
                          const SizedBox(height: 24),
                          Text(
                            '¡Ruleta de castigo para ${losers[_punished]}!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppFonts.display,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: context.onBackdrop,
                            ),
                          ),
                          if (losers.length > 1)
                            Text(
                              'Empataron con menos puntos: cada equipo gira '
                              'su ruleta.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: context.onBackdrop,
                              ),
                            ),
                          const SizedBox(height: 12),
                          RouletteSetupView(
                            key: ValueKey(_punished),
                            initialSource: PunishmentSource.system,
                            initialFields: PunishmentSpinScreen.defaultFields,
                            onSpin: (punishments, spin) =>
                                _spin(losers[_punished], punishments, spin),
                            onSkip: () => setState(() => _punished++),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PairButtons(
                    left: PairButton(
                      color: AppColors.orange,
                      emoji: '🔁',
                      label: 'Jugar otra vez',
                      onPressed: _playAgain,
                    ),
                    right: PairButton(
                      color: AppColors.purple,
                      emoji: '⚙️',
                      label: 'Cambiar configuración',
                      onPressed: _changeConfig,
                    ),
                  ),
                  const SizedBox(height: 4),
                  QuietButton(
                    icon: Icons.arrow_back,
                    label: 'Salir de la categoría',
                    onPressed: () => context.go(Routes.categories),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _joinNames(List<String> names) => names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} y ${names.last}';
}
