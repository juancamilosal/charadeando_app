import 'dart:async';

import 'package:flutter/widgets.dart';

/// Un dibujo que se anima por turnos dentro de un [ArtCycle].
abstract interface class CycleMember {
  /// Posición en el ciclo: se animan de menor a mayor.
  int get order;

  /// Verdadero si ya se puede animar y se ve en la pantalla.
  bool get canPlay;

  /// Hace su animación una vez y termina quieto en su cuadro de reposo.
  Future<void> play();
}

/// Anima los dibujos de adentro uno por uno, en orden y en un ciclo que
/// vuelve a empezar, en vez de todos al mismo tiempo. Los que no se ven en
/// la pantalla se saltan.
class ArtCycle extends StatefulWidget {
  const ArtCycle({super.key, required this.child});

  /// Pausa entre la animación de un dibujo y la del siguiente.
  static const pause = Duration(milliseconds: 500);

  /// Espera al abrir la pantalla, para que primero se vean todas quietas.
  static const firstDelay = Duration(milliseconds: 1500);

  final Widget child;

  /// El ciclo que contiene a [context], o null si no hay: entonces el
  /// dibujo se anima sin parar.
  static ArtCycleState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ArtCycleScope>()?.state;

  @override
  State<ArtCycle> createState() => ArtCycleState();
}

class ArtCycleState extends State<ArtCycle> {
  final _members = <CycleMember>{};
  Timer? _timer;
  bool _playing = false;

  /// Orden del último que se animó; el siguiente es el de orden mayor.
  int _last = -1;

  void add(CycleMember member) => _members.add(member);

  void remove(CycleMember member) => _members.remove(member);

  @override
  void initState() {
    super.initState();
    _schedule(ArtCycle.firstDelay);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule([Duration wait = ArtCycle.pause]) {
    _timer?.cancel();
    _timer = Timer(wait, _next);
  }

  Future<void> _next() async {
    if (!mounted || _playing) return;
    final ready = [
      for (final m in _members)
        if (m.canPlay) m,
    ]..sort((a, b) => a.order.compareTo(b.order));
    if (ready.isNotEmpty) {
      // El siguiente después del último; si no hay, se vuelve a empezar.
      final member = ready.firstWhere(
        (m) => m.order > _last,
        orElse: () => ready.first,
      );
      _last = member.order;
      _playing = true;
      await member.play();
      _playing = false;
    }
    if (mounted) _schedule();
  }

  @override
  Widget build(BuildContext context) =>
      _ArtCycleScope(state: this, child: widget.child);
}

class _ArtCycleScope extends InheritedWidget {
  const _ArtCycleScope({required this.state, required super.child});

  final ArtCycleState state;

  @override
  bool updateShouldNotify(_ArtCycleScope oldWidget) => state != oldWidget.state;
}
