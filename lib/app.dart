import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class CharadeandoApp extends StatelessWidget {
  const CharadeandoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Charadeando',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Los colores del juego no cambian con el modo oscuro del celular.
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
