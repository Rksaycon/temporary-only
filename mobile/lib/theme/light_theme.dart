// ============================================================
//  light_theme.dart
//  Maylaud Design System — Light ThemeData
//
//  Import via app_theme.dart (barrel) or directly:
//    import 'package:may_laud/theme/light_theme.dart';
//    AppTheme.lightTheme()  →  still works (calls buildLightTheme)
// ============================================================

import 'package:flutter/material.dart';

import 'app_theme.dart'; // for shared tokens (spacing, radii, shadows, type)

ThemeData buildLightTheme() {
  final c = AppColors.light; // shorthand

  // ── Typography (light-specific text colors) ─────────────────
  final textTheme = TextTheme(
    displayLarge: AppTheme.displayLarge.copyWith(color: c.textPrimary),
    displayMedium: AppTheme.displayMedium.copyWith(color: c.textPrimary),
    displaySmall: AppTheme.displaySmall.copyWith(color: c.textPrimary),
    headlineLarge: AppTheme.headlineLarge.copyWith(color: c.textPrimary),
    headlineMedium: AppTheme.headlineMedium.copyWith(color: c.textPrimary),
    headlineSmall: AppTheme.headlineSmall.copyWith(color: c.textPrimary),
    titleLarge: AppTheme.titleLarge.copyWith(color: c.textPrimary),
    titleMedium: AppTheme.titleMedium.copyWith(color: c.textPrimary),
    titleSmall: AppTheme.titleSmall.copyWith(color: c.textSecondary),
    bodyLarge: AppTheme.bodyLarge.copyWith(color: c.textSecondary),
    bodyMedium: AppTheme.bodyMedium.copyWith(color: c.textSecondary),
    bodySmall: AppTheme.bodySmall.copyWith(color: c.textMuted),
    labelLarge: AppTheme.labelLarge.copyWith(color: c.textLink),
    labelMedium: AppTheme.labelMedium.copyWith(color: c.textLink),
    labelSmall: AppTheme.labelSmall.copyWith(color: c.textMuted),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // ── Color scheme ──────────────────────────────────────────
    colorScheme: ColorScheme.light(
      primary: c.primary,
      secondary: c.secondary,
      surface: c.surface,
      error: c.textError,
      onPrimary: c.textOnPrimary,
      onSecondary: AppColors.milaorBlue,
      onSurface: c.textPrimary,
      onError: c.textOnPrimary,
    ),

    scaffoldBackgroundColor: c.background,
    textTheme: textTheme,

    // ── AppBar ────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: IconThemeData(color: c.iconPrimary),
    ),

    // ── Cards ─────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: c.cardSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMd),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── Buttons ───────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.textOnPrimary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLg,
          vertical: AppTheme.spacingMd,
        ),
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMd),
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.primary,
        side: BorderSide(color: c.primary),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLg,
          vertical: AppTheme.spacingMd,
        ),
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMd),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),

    // ── Input fields ──────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.all(AppTheme.spacingMd),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMd),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMd),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMd),
        borderSide: BorderSide(color: c.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMd),
        borderSide: BorderSide(color: c.textError),
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(color: c.textMuted),
      hintStyle: textTheme.bodyMedium?.copyWith(color: c.textMuted),
      errorStyle: textTheme.bodySmall?.copyWith(color: c.textError),
    ),

    // ── Divider ───────────────────────────────────────────────
    dividerTheme: DividerThemeData(
      color: c.divider,
      thickness: 1,
      space: 1,
    ),

    // ── Chips ─────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: c.border,
      selectedColor: c.primary,
      labelStyle: textTheme.labelSmall,
      secondaryLabelStyle:
          textTheme.labelSmall?.copyWith(color: c.textOnPrimary),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusCircle),
      ),
    ),

    // ── Bottom nav ────────────────────────────────────────────
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: c.surface,
      selectedItemColor: c.primary,
      unselectedItemColor: c.iconMuted,
      elevation: 8,
    ),

    // ── FAB ───────────────────────────────────────────────────
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primary,
      foregroundColor: c.textOnPrimary,
      elevation: 4,
    ),
  );
}
