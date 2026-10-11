import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/play_background.dart';
import '../widgets/video_view.dart';

/// Miniatura de un video de la galería, guardada mientras la app está
/// abierta.
final videoThumbnailProvider = FutureProvider.family<Uint8List?, String>(
  (ref, id) => ref.read(videoGalleryProvider).thumbnail(id),
);

/// "11 oct 2026 · 9:41 p. m.".
String formatVideoDate(DateTime date) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'a. m.' : 'p. m.';
  return '${date.day} ${months[date.month - 1]} ${date.year} · '
      '$hour:$minute $period';
}

/// Qué borrar al quitar un video de Mis videos.
enum _DeleteChoice { onlyHere, alsoGallery }

/// Pregunta si el video se borra también de la galería y lo borra.
Future<bool> deleteSavedVideo(
  BuildContext context,
  WidgetRef ref,
  SavedVideo video,
) async {
  final choice = await showDialog<_DeleteChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Borrar este video?'),
      content: const Text('¿Borrarlo también de la galería?'),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 4,
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.purple),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.purple),
          onPressed: () => Navigator.pop(context, _DeleteChoice.onlyHere),
          child: const Text('Solo de Mis videos'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _DeleteChoice.alsoGallery),
          child: const Text('También de la galería'),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return false;
  final removed = await ref
      .read(myVideosProvider.notifier)
      .remove(video, fromGallery: choice == _DeleteChoice.alsoGallery);
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            !removed
                ? 'No se borró de la galería.'
                : choice == _DeleteChoice.alsoGallery
                ? 'Video borrado de Mis videos y de la galería.'
                : 'Video quitado de Mis videos. Sigue en tu galería.',
          ),
        ),
      );
  }
  return removed;
}

/// "Mis videos": los videos de los turnos que se guardaron en la galería,
/// del más nuevo al más viejo, con su miniatura y los datos de la partida.
class MyVideosScreen extends ConsumerWidget {
  const MyVideosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(myVideosProvider);
    return PlayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Mis videos'),
          leading: BackButton(
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(Routes.categories),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              const _PrivacyNote(),
              SizedBox(height: 16),
              ...switch (data) {
                AsyncData(:final value) => _content(context, ref, value),
                AsyncError() => [
                  _Message(
                    icon: Icons.error_outline,
                    title: 'No se pudieron cargar tus videos',
                    text: 'Cierra esta sección y vuelve a abrirla.',
                  ),
                ],
                _ => [
                  Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: context.onBackdrop,
                      ),
                    ),
                  ),
                ],
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    MyVideosData data,
  ) {
    return [
      if (data.access == GalleryAccess.limited)
        _AccessCard(
          text:
              'Solo le diste acceso a algunas fotos y videos, así que puede '
              'que no se vean todos.',
          button: 'Elegir videos',
          onPressed: () async {
            await ref.read(videoGalleryProvider).manageLimitedAccess();
            ref.invalidate(myVideosProvider);
          },
        ),
      if (data.access == GalleryAccess.denied)
        _AccessCard(
          text:
              'Charadeando no tiene permiso para ver tu galería. Dalo en los '
              'ajustes del celular para ver tus videos.',
          button: 'Abrir ajustes',
          onPressed: () => ref.read(videoGalleryProvider).openSettings(),
        ),
      if (data.videos.isEmpty)
        const _Message(
          icon: Icons.video_library_outlined,
          title: 'Todavía no hay videos',
          text:
              'Al terminar un turno toca "Ver video" y luego "Guardar": el '
              'video queda en tu galería y aparece aquí.',
        ),
      for (final video in data.videos) ...[
        _VideoCard(
          video: video,
          onTap: () => context.push(Routes.myVideo, extra: video),
          onDelete: () => deleteSavedVideo(context, ref, video),
        ),
        SizedBox(height: 12),
      ],
    ];
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.lock_outline, color: context.onBackdrop, size: 20),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Tus videos se guardan solo en este celular. No los subimos a '
            'ningún lado.',
            style: TextStyle(
              color: context.onBackdrop,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 72, color: context.onBackdrop),
          SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: context.onBackdrop,
            ),
          ),
          SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.onBackdrop.withValues(alpha: 0.8),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.text,
    required this.button,
    required this.onPressed,
  });

  final String text;
  final String button;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PlayPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onPressed, child: Text(button)),
          ],
        ),
      ),
    );
  }
}

/// Un video de la lista: miniatura, grupo y puntos, categoría y fecha.
class _VideoCard extends ConsumerWidget {
  const _VideoCard({
    required this.video,
    required this.onTap,
    required this.onDelete,
  });

  final SavedVideo video;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnail = ref.watch(videoThumbnailProvider(video.assetId)).value;
    const muted = TextStyle(fontSize: 13, color: Color(0xFF6B5A86));
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 112,
                  height: 63,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      thumbnail != null
                          ? Image.memory(thumbnail, fit: BoxFit.cover)
                          : const ColoredBox(color: AppColors.indigo),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      '${video.category} · Ronda ${video.round}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(formatVideoDate(video.savedAt), style: muted),
                    if (video.scoreLine.isNotEmpty)
                      Text(
                        video.scoreLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Borrar',
                icon: const Icon(Icons.delete_outline, color: AppColors.ink),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ver un video de Mis videos, con Compartir y Borrar.
class MyVideoScreen extends ConsumerStatefulWidget {
  const MyVideoScreen({super.key, required this.video});

  final SavedVideo video;

  @override
  ConsumerState<MyVideoScreen> createState() => _MyVideoScreenState();
}

class _MyVideoScreenState extends ConsumerState<MyVideoScreen> {
  late final _file = ref.read(videoGalleryProvider).file(widget.video.assetId);

  Future<void> _share() async {
    final file = await _file;
    if (file != null) await ref.read(videoServiceProvider).share(file.path);
  }

  Future<void> _delete() async {
    if (await deleteSavedVideo(context, ref, widget.video) && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(video.title),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder(
                future: _file,
                builder: (context, snapshot) =>
                    snapshot.connectionState != ConnectionState.done
                    ? const Center(child: CircularProgressIndicator())
                    : VideoView(file: snapshot.data),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${video.category} · Ronda ${video.round} · '
                    '${formatVideoDate(video.savedAt)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.share),
                          label: const Text('Compartir'),
                          onPressed: _share,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Borrar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _delete,
                        ),
                      ),
                    ],
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
