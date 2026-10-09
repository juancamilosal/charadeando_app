import 'package:flutter/material.dart';

import 'router.dart';

class CharadeandoApp extends StatelessWidget {
  const CharadeandoApp({super.key});

  static const _seed = Color(0xFF7B2CBF);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Charadeando',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seed),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      routerConfig: router,
    );
  }
}
