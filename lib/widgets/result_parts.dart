import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme.dart';

/// Partes de las pantallas de resultados (del turno, de la partida rápida y
/// final), para que se vean iguales.

/// "¡Tiempo!" y debajo, más pequeño, de quién o de qué es el resultado.
class ResultTitle extends StatelessWidget {
  const ResultTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final on = context.onBackdrop;
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 36,
            height: 1.1,
            fontWeight: FontWeight.w700,
            color: on,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: on.withValues(alpha: 0.85),
            ),
          ),
        ],
      ],
    );
  }
}

/// Un número en grande (aciertos o puntos) con su nombre debajo.
class BigScore extends StatelessWidget {
  const BigScore({super.key, required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final on = context.onBackdrop;
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 96,
            height: 1,
            fontWeight: FontWeight.w700,
            color: on,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: on,
          ),
        ),
      ],
    );
  }
}

/// Píldoras verde "✓ 9" y naranja "↑ 3 pases".
class HitPassPills extends StatelessWidget {
  const HitPassPills({super.key, required this.hits, required this.passes});

  final int hits;
  final int passes;

  @override
  Widget build(BuildContext context) {
    Widget pill(Color color, IconData icon, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        pill(
          AppColors.green,
          Icons.check,
          '$hits ${hits == 1 ? 'correcto' : 'correctos'}',
        ),
        pill(
          AppColors.orange,
          Icons.arrow_upward,
          '$passes ${passes == 1 ? 'pase' : 'pases'}',
        ),
      ],
    );
  }
}

/// Las palabras del turno en un panel: ✅ si se acertó o ⏭️ si se pasó,
/// con los puntos de cada una si [mode] no es null.
class TurnWordsPanel extends StatelessWidget {
  const TurnWordsPanel({super.key, required this.entries, this.mode});

  final List<TurnEntry> entries;

  /// Puntuación para mostrar "+2" en las acertadas, o null para no
  /// mostrar puntos.
  final ScoringMode? mode;

  @override
  Widget build(BuildContext context) {
    // Un panel blanco, con cada palabra en su fila.
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'No se marcó ninguna palabra.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _EntryRow(entry: entries[i], mode: mode),
                ],
              ],
            ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.mode});

  final TurnEntry entry;
  final ScoringMode? mode;

  @override
  Widget build(BuildContext context) {
    const on = AppColors.ink;
    final hit = entry.outcome == WordOutcome.hit;
    final mode = this.mode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EEFD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry.word.text,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: on,
              ),
            ),
          ),
          // Los puntos de la palabra según la puntuación elegida: por
          // frase, +1; por palabra, uno por cada palabra. Las pasadas, 0.
          if (mode != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: hit ? AppColors.green : on.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                hit ? '+${mode.pointsFor(entry.word.wordCount)}' : '0',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: hit ? Colors.white : on.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Text(hit ? '✅' : '⏭️', style: const TextStyle(fontSize: 20)),
        ],
      ),
    );
  }
}

/// Marcador pequeño con todos los grupos y sus puntos; el que va ganando,
/// resaltado.
class MiniScoreboard extends StatelessWidget {
  const MiniScoreboard({super.key, required this.groups, required this.scores});

  final List<Group> groups;
  final List<int> scores;

  @override
  Widget build(BuildContext context) {
    final best = scores.fold(0, (a, b) => a > b ? a : b);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < groups.length; i++)
          _ScoreChip(
            name: groups[i].name,
            score: scores[i],
            leader: best > 0 && scores[i] == best,
          ),
      ],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.name,
    required this.score,
    required this.leader,
  });

  final String name;
  final int score;
  final bool leader;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: leader ? AppColors.yellow : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: leader ? AppColors.ink : const Color(0xFFE3D7F7),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leader) ...[
            const Icon(Icons.emoji_events, size: 16, color: AppColors.ink),
            const SizedBox(width: 4),
          ],
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$score',
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.purple,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Ver video", blanco y de todo el ancho, o el avance mientras se escriben
/// las palabras en el video.
class VideoButton extends StatelessWidget {
  const VideoButton({super.key, required this.video});

  final TurnVideoState video;

  @override
  Widget build(BuildContext context) {
    final ready = video.status == TurnVideoStatus.ready;
    final percent = (video.progress * 100).round();
    final light = context.backdrop.light;
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.purple,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.75),
        disabledForegroundColor: AppColors.purple.withValues(alpha: 0.8),
        minimumSize: const Size.fromHeight(60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        side: light
            ? const BorderSide(color: AppColors.purple, width: 2)
            : null,
      ),
      onPressed: ready ? () => context.push(Routes.video) : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (ready)
            const Text('🎬', style: TextStyle(fontSize: 22))
          else
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.purple,
                value: video.progress > 0 ? video.progress : null,
              ),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(ready ? 'Ver video' : 'Preparando video… $percent%'),
          ),
        ],
      ),
    );
  }
}
