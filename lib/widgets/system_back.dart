import 'package:flutter/widgets.dart';

/// Hace que el botón atrás del celular (o el gesto de volver) haga lo mismo
/// que la flecha de arriba. Las pantallas que se abren con `context.go` no
/// tienen otra debajo: sin esto, Android cerraba la app hacia el fondo.
class SystemBack extends StatelessWidget {
  const SystemBack({super.key, required this.onBack, required this.child});

  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) onBack();
    },
    child: child,
  );
}
