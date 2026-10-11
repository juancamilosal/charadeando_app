import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/providers.dart';
import 'router.dart';
import 'theme.dart';

class CharadeandoApp extends ConsumerStatefulWidget {
  const CharadeandoApp({super.key});

  @override
  ConsumerState<CharadeandoApp> createState() => _CharadeandoAppState();
}

class _CharadeandoAppState extends ConsumerState<CharadeandoApp> {
  late final GoRouter _router = createRouter(
    welcomeSeen: () => ref.read(welcomeSeenProvider),
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Charadeando',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(ref.watch(backdropProvider)),
      // Los colores del juego no cambian con el modo oscuro del celular.
      themeMode: ThemeMode.light,
      routerConfig: _router,
    );
  }
}
