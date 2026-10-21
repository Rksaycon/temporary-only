// ============================================================
//  app_theme.dart
//  Maylaud Design System — Barrel & Shared Design Tokens
//
//  This file is the SINGLE import most widgets need:
//    import 'package:may_laud/theme/app_theme.dart';
//
//  It re-exports:
//    • AppColors          – every color + font-color token
//    • buildLightTheme()  – light ThemeData
//    • buildDarkTheme()   – dark ThemeData
//
//  It also owns all mode-independent design tokens
//  (spacing, radii, shadows, typography base styles, helpers)
//  so light_theme.dart and dark_theme.dart import ONE file.
// ============================================================

export 'app_colors.dart';
export 'light_theme.dart';
export 'dark_theme.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'light_theme.dart';
import 'dark_theme.dart';

// ── Compatibility shim ───────────────────────────────────────
// Existing code calls AppTheme.lightTheme() / AppTheme.darkTheme().
// Keep those working without any migration cost.

abstract final class AppTheme {
  // ── Neutral gray shims (canonical values live in AppColors) ──────────
  static const Color neutralGray200 = AppColors.neutralGray200;
  static const Color neutralGray500 = AppColors.neutralGray500;
  static const Color neutralGray800 = AppColors.neutralGray800;

  // ── Brand color shims (canonical values live in AppColors) ───────────
  static Color get milaorBlue       => AppColors.milaorBlue;
  static const Color philippineGold = AppColors.philippineGold;
  static const Color philippineRed  = AppColors.error;


  // ── Theme factories (delegates to dedicated files) ──────────
  static ThemeData lightTheme() => buildLightTheme();
  static ThemeData darkTheme()  => buildDarkTheme();

  // ============================================================
  //  SHARED DESIGN TOKENS
  //  These are mode-independent and imported by both theme files.
  // ============================================================

  // ── Spacing ──────────────────────────────────────────────────
  static const double spacingXs  =  4.0;
  static const double spacingSm  =  8.0;
  static const double spacingMd  = 16.0;
  static const double spacingLg  = 24.0;
  static const double spacingXl  = 32.0;
  static const double spacingXxl = 48.0;
  static const double spacingXxxl = 64.0;

  // ── Border radii ─────────────────────────────────────────────
  static const double borderRadiusXs     =  4.0;
  static const double borderRadiusSm     =  8.0;
  static const double borderRadiusMd     = 12.0;
  static const double borderRadiusLg     = 16.0;
  static const double borderRadiusXl     = 24.0;
  static const double borderRadiusCircle = 100.0;

  // ── Shadows ───────────────────────────────────────────────────
  static const List<BoxShadow> shadowXs = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0x29000000), blurRadius: 16, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> shadowXl = [
    BoxShadow(color: Color(0x3D000000), blurRadius: 24, offset: Offset(0, 12)),
  ];

  // ── Animation durations ───────────────────────────────────────
  static const Duration animationFast   = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow   = Duration(milliseconds: 500);

  // ============================================================
  //  BASE TYPOGRAPHY
  //  Font size, weight, and line-height only — NO hard-coded
  //  colors here. Each theme file applies its own color via
  //  .copyWith(color: ...) when building the TextTheme.
  // ============================================================

  static TextStyle displayLarge = GoogleFonts.poppins(
    fontSize: 57, fontWeight: FontWeight.w700, height: 1.12,
  );
  static TextStyle displayMedium = GoogleFonts.poppins(
    fontSize: 45, fontWeight: FontWeight.w700, height: 1.16,
  );
  static TextStyle displaySmall = GoogleFonts.poppins(
    fontSize: 36, fontWeight: FontWeight.w700, height: 1.22,
  );
  static TextStyle headlineLarge = GoogleFonts.poppins(
    fontSize: 32, fontWeight: FontWeight.w700, height: 1.25,
  );
  static TextStyle headlineMedium = GoogleFonts.poppins(
    fontSize: 28, fontWeight: FontWeight.w600, height: 1.29,
  );
  static TextStyle headlineSmall = GoogleFonts.poppins(
    fontSize: 24, fontWeight: FontWeight.w600, height: 1.33,
  );
  static TextStyle titleLarge = GoogleFonts.inter(
    fontSize: 22, fontWeight: FontWeight.w600, height: 1.27,
  );
  static TextStyle titleMedium = GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.w600, height: 1.5,
  );
  static TextStyle titleSmall = GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w600, height: 1.43,
  );
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.w400, height: 1.5,
  );
  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w400, height: 1.43,
  );
  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.w400, height: 1.33,
  );
  static TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w600, height: 1.43,
  );
  static TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.w600, height: 1.33,
  );
  static TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w600, height: 1.45,
  );

  // ============================================================
  //  HELPER METHODS
  // ============================================================

  static TextStyle responsiveText({
    required BuildContext context,
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  /// Card decoration — uses explicit color; pass via AppColors.of(context).cardSurface
  static BoxDecoration cardDecoration({
    required Color surface,
    bool elevated = true,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(borderRadiusMd),
      boxShadow: elevated ? shadowSm : null,
      border: elevated ? null : Border.all(color: borderColor ?? const Color(0xFFE9ECEF)),
    );
  }

  static BoxDecoration primaryCardDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0056A3), Color(0xFF0077CC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadiusLg),
      boxShadow: shadowMd,
    );
  }

  static BoxDecoration outlineDecoration({Color color = const Color(0xFF0056A3)}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadiusMd),
      border: Border.all(color: color),
    );
  }

  // Padding helpers
  static EdgeInsets paddingAll(double v)        => EdgeInsets.all(v);
  static EdgeInsets paddingHorizontal(double v) => EdgeInsets.symmetric(horizontal: v);
  static EdgeInsets paddingVertical(double v)   => EdgeInsets.symmetric(vertical: v);
  static EdgeInsets paddingSym({double horizontal = 0, double vertical = 0}) =>
      EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);

  // Margin helpers
  static EdgeInsets marginAll(double v)        => EdgeInsets.all(v);
  static EdgeInsets marginHorizontal(double v) => EdgeInsets.symmetric(horizontal: v);
  static EdgeInsets marginVertical(double v)   => EdgeInsets.symmetric(vertical: v);

  // Screen helpers
  static double getScreenWidth(BuildContext context)  => MediaQuery.of(context).size.width;
  static double getScreenHeight(BuildContext context) => MediaQuery.of(context).size.height;
  static bool isMobile(BuildContext context)  => getScreenWidth(context) < 600;
  static bool isTablet(BuildContext context)  =>
      getScreenWidth(context) >= 600 && getScreenWidth(context) < 1200;
  static bool isDesktop(BuildContext context) => getScreenWidth(context) >= 1200;
}