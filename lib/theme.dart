import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFF0F131B);
  static const surface = Color(0xFF1C2027);
  static const input = Color(0xFF06090E);
  static const text = Color(0xFFDFE2ED);
  static const muted = Color(0xFF94A3B8);
  static const primary = Color(0xFF4EDEA3);
  static const onPrimary = Color(0xFF003824);
  static const error = Color(0xFFFFB4AB);
  static const border = Color(0x2994A3B8);
}

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.dark(
    surface: AppColors.background,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    error: AppColors.error,
  ),
  textTheme: GoogleFonts.geistTextTheme(ThemeData.dark().textTheme),
  appBarTheme: const AppBarTheme(backgroundColor: AppColors.background),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.input,
    prefixIconColor: AppColors.muted,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  ),
);

TextStyle heading(double size) => GoogleFonts.hankenGrotesk(
    fontSize: size, fontWeight: FontWeight.w700, color: AppColors.text);
