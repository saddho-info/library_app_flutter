import 'package:flutter/material.dart';

/// Ink & Paper tokens adapted for Material (parity with web Phase 1).
class AppColors {
  static const background = Color(0xFFF4F6F8);
  static const foreground = Color(0xFF0F172A);
  static const card = Color(0xFFFFFFFF);
  static const cardForeground = Color(0xFF0F172A);
  static const primary = Color(0xFF164E63);
  static const primaryForeground = Color(0xFFF0FDFA);
  static const secondary = Color(0xFFE8EEF1);
  static const secondaryForeground = Color(0xFF164E63);
  static const muted = Color(0xFFEEF2F6);
  static const mutedForeground = Color(0xFF64748B);
  static const accent = Color(0xFFE8EEF1);
  static const accentForeground = Color(0xFF164E63);
  static const border = Color(0xFFE2E8F0);
  static const input = Color(0xFFE2E8F0);
  static const ring = Color(0xFF164E63);
  static const destructive = Color(0xFFDC2626);
  static const destructiveForeground = Color(0xFFFEF2F2);
  static const success = Color(0xFF15803D);
  static const warning = Color(0xFFB45309);
  static const info = Color(0xFF1D4ED8);

  static const ink50 = Color(0xFFECFEFF);
  static const ink100 = Color(0xFFCFFAFE);
  static const ink700 = Color(0xFF0E7490);
  static const ink900 = Color(0xFF164E63);
  static const ink950 = Color(0xFF083344);

  /// Alias kept for screens that styled muted body copy.
  static const mutedText = mutedForeground;
}

class AppRadii {
  static const sm = 4.0;
  static const md = 6.0;
  static const lg = 8.0;
  static const xl = 12.0;
}

ThemeData buildAppTheme() {
  const radius = AppRadii.lg;
  final colorScheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.primaryForeground,
    secondary: AppColors.secondary,
    onSecondary: AppColors.secondaryForeground,
    surface: AppColors.card,
    onSurface: AppColors.foreground,
    error: AppColors.destructive,
    onError: AppColors.destructiveForeground,
    outline: AppColors.border,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    dividerColor: AppColors.border,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.foreground,
      displayColor: AppColors.foreground,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.card,
      foregroundColor: AppColors.foreground,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.foreground,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: AppColors.border),
      ),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.secondary,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? AppColors.primary : AppColors.mutedForeground,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 22,
          color: selected ? AppColors.primary : AppColors.mutedForeground,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AppColors.input),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AppColors.ring, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryForeground,
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(44),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink950,
      contentTextStyle: const TextStyle(color: AppColors.primaryForeground),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );
}
