import 'package:flutter/material.dart';

/// Paleta adaptativa claro/escuro.
///
/// Como trocar: `AppColors.isDark = true/false` (via `ThemeController`).
/// Cores que NÃO mudam (`primary`, `accent`, `danger`) seguem `const`,
/// então `const Icon(color: AppColors.primary)` continua compilando.
/// As demais viraram getters — não usar dentro de `const`.
class AppColors {
  static bool isDark = false;

  // --- Fixas (iguais nos dois temas) ---
  static const primary = Color(0xFF1565C0); // Azul principal
  static const accent = Color(0xFF00C897); // Verde ação
  static const danger = Color(0xFFE53935); // Vermelho

  // --- Adaptativas ---
  static Color get background =>
      isDark ? const Color(0xFF121417) : const Color(0xFFF5F7FA);
  static Color get surface =>
      isDark ? const Color(0xFF1E2126) : Colors.white;
  static Color get primarySoft =>
      isDark ? const Color(0xFF0D2B4D) : const Color(0xFFE3F2FD);
  static Color get textPrimary =>
      isDark ? const Color(0xFFE8EAED) : const Color(0xFF1F2933);
  static Color get textSecondary =>
      isDark ? const Color(0xFF9AA0A6) : const Color(0xFF7B8794);
  static Color get borderSoft =>
      isDark ? const Color(0xFF3C4043) : const Color(0xFFE4E7EB);
}

class AppTextStyles {
  // Não-const de propósito: cores vêm dos getters adaptativos.
  static TextStyle get h1 => TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get h2 => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get subtitle => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle get body => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get caption => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get chip => const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
      );
}

ThemeData buildAppTheme({bool dark = false}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: AppColors.primary,
    secondary: AppColors.accent,
    surface: dark ? const Color(0xFF1E2126) : Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor:
        dark ? const Color(0xFF121417) : const Color(0xFFF5F7FA),
    primaryColor: AppColors.primary,
    fontFamily: 'Roboto',
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF1E2126) : Colors.white,
      foregroundColor: dark ? Colors.white : const Color(0xFF1F2933),
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 44,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: dark ? Colors.white : const Color(0xFF1F2933),
      ),
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF1E2126) : Colors.white,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xFF1E2126) : Colors.white,
    ),
  );
}
