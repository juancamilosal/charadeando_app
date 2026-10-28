import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../widgets/video_view.dart';

/// Reproduce el video del último turno, con opción de guardarlo en la
/// galería o compartirlo. Al guardarlo también aparece en Mis videos.
class VideoScreen extends ConsumerStatefulWidget {
  const VideoScreen({super.key});

  @override
  ConsumerState<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends ConsumerState<VideoScreen> {
  bool _saving = false;

  String? get _path => ref.read(turnVideoProvider).path;

  Future<void> _save() async {
    setState(() => _saving = true);
    final message = await ref.read(turnVideoProvider.notifier).save();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _share() async {
    final path = _path;
    if (path != null) await ref.read(videoServiceProvider).share(path);
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    final saved = ref.watch(turnVideoProvider).saved;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: path == null
                  ? const Center(
                      child: Text(
                        'No hay video de este turno.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : VideoView(file: File(path)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: Icon(saved ? Icons.check : Icons.download),
                          label: Text(saved ? 'Guardado' : 'Guardar'),
                          onPressed: _saving || saved || path == null
                              ? null
                              : _save,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.share),
                          label: const Text('Compartir'),
                          onPressed: _share,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => context.pop(),
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
