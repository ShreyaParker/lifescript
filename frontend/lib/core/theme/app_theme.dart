import 'package:flutter/material.dart';

class AppPalette {
  static const ink = Color(0xFF25243A);
  static const muted = Color(0xFF6E6C82);
  static const primary = Color(0xFF6A57D5);
  static const lavender = Color(0xFFEFEBFF);
  static const mint = Color(0xFFE6F3EE);
  static const line = Color(0xFFE9E7F0);
  static const background = Color(0xFFF8F7FC);
}

ThemeData lifeScriptTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppPalette.primary).copyWith(
    primary: AppPalette.primary,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: AppPalette.ink,
    onSurfaceVariant: AppPalette.muted,
    outline: const Color(0xFFC7C2D9),
    outlineVariant: AppPalette.line,
    primaryContainer: AppPalette.lavender,
    onPrimaryContainer: const Color(0xFF46358F),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Inter',
  );
  final text = base.textTheme.apply(
    bodyColor: AppPalette.ink,
    displayColor: AppPalette.ink,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppPalette.background,
    textTheme: text.copyWith(
      headlineLarge: const TextStyle(
        fontFamily: 'Manrope',
        color: AppPalette.ink,
        fontSize: 36,
        height: 1.2,
        fontWeight: FontWeight.w800,
        fontVariations: [FontVariation('wght', 800)],
        letterSpacing: -1.3,
      ),
      headlineMedium: const TextStyle(
        fontFamily: 'Manrope',
        color: AppPalette.ink,
        fontSize: 30,
        height: 1.25,
        fontWeight: FontWeight.w800,
        fontVariations: [FontVariation('wght', 800)],
        letterSpacing: -1,
      ),
      headlineSmall: const TextStyle(
        fontFamily: 'Manrope',
        color: AppPalette.ink,
        fontSize: 26,
        height: 1.3,
        fontWeight: FontWeight.w800,
        fontVariations: [FontVariation('wght', 800)],
        letterSpacing: -.7,
      ),
      titleLarge: const TextStyle(
        fontFamily: 'Manrope',
        color: AppPalette.ink,
        fontSize: 20,
        height: 1.4,
        fontWeight: FontWeight.w700,
        fontVariations: [FontVariation('wght', 700)],
        letterSpacing: -.4,
      ),
      titleMedium: const TextStyle(
        fontFamily: 'Inter',
        color: AppPalette.ink,
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: const TextStyle(
        fontFamily: 'Inter',
        color: AppPalette.ink,
        fontSize: 15,
        height: 1.7,
      ),
      bodyMedium: const TextStyle(
        fontFamily: 'Inter',
        color: AppPalette.ink,
        fontSize: 14,
        height: 1.65,
      ),
      bodySmall: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        height: 1.6,
        color: AppPalette.muted,
      ),
      labelLarge: const TextStyle(
        fontFamily: 'Inter',
        color: AppPalette.ink,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: .1,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppPalette.background,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppPalette.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: AppPalette.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFAF9FD),
      hintStyle: const TextStyle(color: Color(0xFF9793AA), fontSize: 14),
      contentPadding: const EdgeInsets.all(20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppPalette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppPalette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppPalette.primary, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: Colors.white,
      indicatorColor: AppPalette.lavender,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppPalette.primary
              : AppPalette.muted,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      side: const BorderSide(color: AppPalette.line),
      backgroundColor: Colors.white,
      padding: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(color: AppPalette.line, thickness: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppPalette.primary,
      linearTrackColor: AppPalette.lavender,
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
