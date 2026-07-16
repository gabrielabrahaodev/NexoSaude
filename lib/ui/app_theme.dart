import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF5F7FA);
  static const surface = Colors.white;
  static const primary = Color(0xFF1565C0);      // Azul principal
  static const primarySoft = Color(0xFFE3F2FD);  // Azul clarinho
  static const accent = Color(0xFF00C897);       // Verde ação
  static const danger = Color(0xFFE53935);       // Vermelho
  static const textPrimary = Color(0xFF1F2933);  // Preto suave
  static const textSecondary = Color(0xFF7B8794);
  static const borderSoft = Color(0xFFE4E7EB);
}

class AppTextStyles {
  static const h1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const subtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const chip = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      background: AppColors.background,
      surface: AppColors.surface,
    ),
  );
}