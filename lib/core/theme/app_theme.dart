import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const background = Color(0xFF0A0F1E);
  static const surface = Color(0xFF141C2E);
  static const surfaceElevated = Color(0xFF1A2540);
  static const border = Color(0xFF1E2D42);

  static const accent = Color(0xFF00C2FF);
  static const accentDark = Color(0xFF0095C4);

  static const alertRed = Color(0xFFFF3B3B);
  static const safeGreen = Color(0xFF00E676);
  static const warningAmber = Color(0xFFFFB300);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8A9BB0);
  static const textMuted = Color(0xFF3D4F66);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        surface: AppColors.surface,
        onPrimary: Colors.black,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: GoogleFonts.inter(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle headline(BuildContext context) =>
      GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5);

  static TextStyle title(BuildContext context) =>
      GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

  static TextStyle body(BuildContext context) =>
      GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary);

  static TextStyle caption(BuildContext context) =>
      GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary);

  static TextStyle label(BuildContext context) =>
      GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.8);
}
