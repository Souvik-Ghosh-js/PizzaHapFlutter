import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_config.dart';

class AppTheme {
  static const Color primary = Color(AppColors.primary);
  static const Color primaryDark = Color(AppColors.primaryDark);
  static const Color accent = Color(AppColors.accent);
  static const Color background = Color(AppColors.background);
  static const Color textPrimary = Color(AppColors.textPrimary);
  static const Color textSecondary = Color(AppColors.textSecondary);
  static const Color success = Color(AppColors.success);
  static const Color warning = Color(AppColors.warning);
  static const Color error = Color(AppColors.error);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: Colors.white,
      error: error,
    ),
    scaffoldBackgroundColor: background,
    fontFamily: GoogleFonts.nunito().fontFamily,
    textTheme: GoogleFonts.nunitoTextTheme().copyWith(
      displayLarge: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 32, color: textPrimary),
      headlineLarge: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 24, color: textPrimary),
      headlineMedium: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 20, color: textPrimary),
      titleLarge: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 18, color: textPrimary),
      titleMedium: GoogleFonts.nunito(fontWeight: FontWeight.w600, fontSize: 16, color: textPrimary),
      bodyLarge: GoogleFonts.nunito(fontWeight: FontWeight.w500, fontSize: 16, color: textPrimary),
      bodyMedium: GoogleFonts.nunito(fontWeight: FontWeight.w400, fontSize: 14, color: textPrimary),
      labelLarge: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: GoogleFonts.nunito(
        fontWeight: FontWeight.w800, fontSize: 20, color: textPrimary,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary, width: 1.5),
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: GoogleFonts.nunito(color: const Color(AppColors.textHint), fontSize: 14),
      errorStyle: GoogleFonts.nunito(color: error, fontSize: 12, fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade100),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primary,
      unselectedItemColor: Color(0xFF999999),
      type: BottomNavigationBarType.fixed,
      elevation: 16,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey.shade100,
      selectedColor: primary,
      labelStyle: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1A1A1A),
      contentTextStyle: GoogleFonts.nunito(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: DividerThemeData(color: Colors.grey.shade100, thickness: 1),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      elevation: 8,
    ),
  );
}
