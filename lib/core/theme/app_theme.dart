import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema visual de Staydoct.
///
/// Se construye a mano (sin fuentes descargables) para que la app funcione
/// incluso con conectividad limitada, algo crítico en una emergencia.
abstract final class AppTheme {
  static ThemeData get light => _build(
        brightness: Brightness.light,
        background: AppColors.background,
        surface: AppColors.surface,
        border: AppColors.border,
        textPrimary: AppColors.textPrimary,
        textSecondary: AppColors.textSecondary,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        border: AppColors.darkBorder,
        textPrimary: AppColors.darkTextPrimary,
        textSecondary: AppColors.darkTextSecondary,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? const Color(0xFF6FC7FF) : AppColors.navy,
      onPrimary: isDark ? AppColors.navy : Colors.white,
      secondary: AppColors.mint,
      error: AppColors.emergency,
      surface: surface,
      onSurface: textPrimary,
      outline: border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, textPrimary, textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: isDark
            ? AppColors.navySoft
            : AppColors.navy.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkBackground : AppColors.surfaceMuted,
        hintStyle: TextStyle(color: textSecondary, fontSize: 14.5),
        labelStyle: TextStyle(color: textSecondary, fontSize: 14.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.mint, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.emergency, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        selectedColor: AppColors.emergencySoft,
        side: BorderSide(color: border),
        labelStyle: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.mint,
      ),
    );
  }

  static TextTheme _textTheme(
    TextTheme base,
    Color textPrimary,
    Color textSecondary,
  ) {
    TextStyle style(double size, FontWeight weight, {double? height, Color? color, double? ls}) =>
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: ls,
          color: color ?? textPrimary,
        );

    return base.copyWith(
      displaySmall: style(34, FontWeight.w800, height: 1.1, ls: -1),
      headlineMedium: style(28, FontWeight.w800, height: 1.15, ls: -0.8),
      headlineSmall: style(23, FontWeight.w700, height: 1.2, ls: -0.5),
      titleLarge: style(19, FontWeight.w700, height: 1.25, ls: -0.3),
      titleMedium: style(16, FontWeight.w700, height: 1.3),
      bodyLarge: style(15.5, FontWeight.w500, height: 1.5),
      bodyMedium: style(14.2, FontWeight.w500, height: 1.5, color: textSecondary),
      bodySmall: style(12.5, FontWeight.w500, height: 1.4, color: textSecondary),
      labelLarge: style(14, FontWeight.w700),
      labelSmall: style(11, FontWeight.w600, ls: 0.2, color: textSecondary),
    );
  }
}
