import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors from the SubBox design system (substrack/DESIGN.md).
class AppColors {
  static const background = Color(0xFF0F131B);
  static const surface = Color(0xFF1C2027);
  static const surfaceHigh = Color(0xFF262A32);
  static const input = Color(0xFF0A0E15);
  static const text = Color(0xFFDFE2ED);
  static const muted = Color(0xFF94A3B8);
  static const primary = Color(0xFF4EDEA3);
  static const primaryDark = Color(0xFF10B981);
  static const onPrimary = Color(0xFF003824);
  static const warning = Color(0xFFFFB95F);
  static const error = Color(0xFFFFB4AB);
  static const danger = Color(0xFF93000A);
  static const border = Color(0x2994A3B8);
}

OutlineInputBorder _border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );

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
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    scrolledUnderElevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.input,
    prefixIconColor: AppColors.muted,
    hintStyle: const TextStyle(color: Color(0xFF64748B)),
    enabledBorder: _border(AppColors.border),
    focusedBorder: _border(AppColors.primary),
    border: _border(AppColors.border),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.surfaceHigh,
    selectedColor: AppColors.primaryDark,
    labelStyle: const TextStyle(color: AppColors.text, fontSize: 13),
    secondaryLabelStyle:
        const TextStyle(color: AppColors.onPrimary, fontSize: 13),
    side: BorderSide.none,
    showCheckmark: false,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: SegmentedButton.styleFrom(
      backgroundColor: AppColors.input,
      selectedBackgroundColor: AppColors.primaryDark,
      selectedForegroundColor: AppColors.onPrimary,
      foregroundColor: AppColors.text,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  switchTheme: SwitchThemeData(
    trackColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? AppColors.primaryDark : null),
    thumbColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? Colors.white : null),
  ),
);

TextStyle heading(double size, {Color color = AppColors.text}) =>
    GoogleFonts.hankenGrotesk(
        fontSize: size, fontWeight: FontWeight.w700, color: color);

/// Small uppercase label, e.g. "BILLING AMOUNT".
const labelStyle = TextStyle(
    color: AppColors.muted,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8);
