import 'package:flutter/material.dart';

/// Paleta de Staydoct.
///
/// Azul profundo (confianza clínica) + coral (emergencia) + verde menta
/// (confirmación y signos vitales estables).
abstract final class AppColors {
  static const Color navy = Color(0xFF0B1F33);
  static const Color navySoft = Color(0xFF16324F);
  static const Color emergency = Color(0xFFE23D4C);
  static const Color emergencyDark = Color(0xFFB3202D);
  static const Color emergencySoft = Color(0xFFFFE8EA);
  static const Color mint = Color(0xFF14A085);
  static const Color mintSoft = Color(0xFFE3F7F1);
  static const Color amber = Color(0xFFF2A93B);
  static const Color amberSoft = Color(0xFFFEF3E2);
  static const Color dangerSoft = Color(0xFFFDECEC);
  static const Color background = Color(0xFFF4F6FA);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFEDF1F6);
  static const Color border = Color(0xFFDDE5EE);
  static const Color textPrimary = Color(0xFF0B1F33);
  static const Color textSecondary = Color(0xFF5B6B7C);
  static const Color textTertiary = Color(0xFF8A9AAB);

  static const Color darkBackground = Color(0xFF071624);
  static const Color darkSurface = Color(0xFF0F2439);
  static const Color darkBorder = Color(0xFF1F3A55);
  static const Color darkTextPrimary = Color(0xFFF3F7FB);
  static const Color darkTextSecondary = Color(0xFFA9BACB);
}
