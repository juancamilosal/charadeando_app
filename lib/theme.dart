import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paleta del juego. La app siempre usa estos colores, aunque el celular
/// esté en modo oscuro.
abstract final class AppColors {
  static const purple = Color(0xFF6A1BE0);
  static const magenta = Color(0xFFE5197E);
  static const pink = Color(0xFFFF4F8B);
  static const orange = Color(0xFFFF8A00);
  static const yellow = Color(0xFFFFD23F);
  static const turquoise = Color(0xFF1FC8B4);
  static const blue = Color(0xFF2F80FF);
  static const green = Color(0xFF18C26B);
  static const coral = Color(0xFFFF5A5F);
  static const indigo = Color(0xFF3D2C9E);

  /// Morado oscuro para textos sobre fondos claros.
  static const ink = Color(0xFF2B0A57);

  /// Fondo de las pantallas.
  static const background = [Color(0xFF7B2FF7), Color(0xFFC21FD6), pink];

  /// Fondo de la palabra durante el turno.
  static const word = [blue, turquoise];

  /// Fondo de la cuenta regresiva.
  static const countdown = [orange, magenta];
}

abstract final class AppFonts {
  /// Títulos y botones: letra redondeada, de juego.
  static const display = 'Fredoka';

  /// Textos.
  static const body = 'Nunito';
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.purple).copyWith(
    primary: AppColors.purple,
    onPrimary: Colors.white,
    secondary: AppColors.yellow,
    onSecondary: AppColors.ink,
    surface: Colors.white,
    onSurface: AppColors.ink,
  );
  final base = ThemeData(colorScheme: scheme, fontFamily: AppFonts.body);
  const display = TextStyle(fontFamily: AppFonts.display);
  final text = base.textTheme
      .copyWith(
        displayLarge: base.textTheme.displayLarge?.merge(display),
        displayMedium: base.textTheme.displayMedium?.merge(display),
        displaySmall: base.textTheme.displaySmall?.merge(display),
        headlineLarge: base.textTheme.headlineLarge?.merge(display),
        headlineMedium: base.textTheme.headlineMedium?.merge(display),
        headlineSmall: base.textTheme.headlineSmall?.merge(display),
        titleLarge: base.textTheme.titleLarge?.merge(display),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      )
      .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.purple,
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.display,
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.ink,
        disabledBackgroundColor: Colors.white24,
        disabledForegroundColor: Colors.white70,
        minimumSize: const Size.fromHeight(56),
        shape: shape,
        textStyle: const TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white, width: 2),
        minimumSize: const Size.fromHeight(52),
        shape: shape,
        textStyle: const TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF4EEFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.ink,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
