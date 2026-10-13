import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/services.dart';

/// Calla la música de fondo mientras [child] está abierta: el turno (con
/// la cámara grabando) y los videos, que tienen su propio sonido.
class MusicSilence extends ConsumerStatefulWidget {
  const MusicSilence({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MusicSilence> createState() => _MusicSilenceState();
}

class _MusicSilenceState extends ConsumerState<MusicSilence> {
  late final BackgroundMusic _music = ref.read(backgroundMusicProvider);

  @override
  void initState() {
    super.initState();
    _music.hold();
  }

  @override
  void dispose() {
    _music.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
