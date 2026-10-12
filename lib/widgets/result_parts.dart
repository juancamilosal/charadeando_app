import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme.dart';
import 'play_background.dart';

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
        pill(AppColors.green, Icons.check, '$hits'),
        pill(
          AppColors.orange,
          Icons.arrow_upward,
          '$passes ${passes == 1 ? 'pase' : 'pases'}',
        ),
      ],
    );
  }
}

/// Las palabras del turno en un panel: ✅ si se acertó (con sus puntos si
/// [mode] no es null) o ⏭️ si se pasó.
class TurnWordsPanel extends StatelessWidget {
  const TurnWordsPanel({super.key, required this.entries, this.mode});

  final List<TurnEntry> entries;

  /// Puntuación para mostrar "+2" en las acertadas, o null para no
  /// mostrar puntos.
  final ScoringMode? mode;

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: entries.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No se marcó ninguna palabra.',
                textAlign: TextAlign.center,
              ),
            )
          : Column(
              children: [
                for (final entry in entries)
                  _EntryRow(entry: entry, mode: mode),
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
    final hit = entry.outcome == WordOutcome.hit;
    final mode = this.mode;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(hit ? '✅' : '⏭️', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.word.text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: hit ? FontWeight.w800 : FontWeight.w600,
                color: hit ? AppColors.ink : const Color(0xFF8A7AA6),
              ),
            ),
          ),
          if (hit && mode != null)
            Text(
              '+${mode.pointsFor(entry.word.wordCount)}',
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.green,
              ),
            ),
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
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.purple,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.75),
        disabledForegroundColor: AppColors.purple.withValues(alpha: 0.8),
        side: light
            ? const BorderSide(color: AppColors.purple, width: 2)
            : null,
      ),
      icon: ready
          ? const Icon(Icons.play_circle_fill)
          : SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.purple,
                value: video.progress > 0 ? video.progress : null,
              ),
            ),
      label: Text(ready ? 'Ver video' : 'Preparando video… $percent%'),
      onPressed: ready ? () => context.push(Routes.video) : null,
    );
  }
}
