// ============================================================
//  app_colors.dart
//  Maylaud Design System — Single source of truth for every
//  color and font-color token used across the app.
//
//  Usage:
//    import 'package:may_laud/theme/app_colors.dart';
//
//    // Brand / semantic colors (mode-independent)
//    AppColors.milaorBlue
//    AppColors.error
//
//    // Mode-aware surface / text colors
//    AppColors.light.textPrimary
//    AppColors.dark.textPrimary
//
//    // Resolve automatically from BuildContext
//    AppColors.of(context).textPrimary
// ============================================================

import 'package:flutter/material.dart';

// ── Brand & Semantic ─────────────────────────────────────────

abstract final class AppColors {
  // --- Brand palette ---
  //
  // The brand colors below are intentionally *mutable* rather than `const`.
  // The web admin's "App Customization" page writes a brand + accent color to
  // the Supabase `app_theme` table; the app applies them through [applyBrand]
  // (see providers/app_theme_provider.dart). Because every screen already reads
  // these same names, one change repaints the whole app with no per-screen
  // edits. The values here are just the shipped defaults.
  static Color milaorBlue      = const Color(0xFF0056A3); // Primary / accent
  static const Color philippineGold  = Color(0xFFFDB913); // Secondary
  static const Color philippineRed   = Color(0xFFCE1126); // Accent
  static const Color philippineGreen = Color(0xFF0C5A43); // Success

  // --- Heritage purple palette (used in home, profile, sign-in, sheets) ---
  static Color heritagePurple = const Color(0xFF4C229C); // main brand purple
  static Color riverFlow      = const Color(0xFF643EB5); // mid purple
  static Color deepAnchor     = const Color(0xFF24005B); // dark purple anchor

  /// Gradient used on home header, profile header, sign-in screen, etc.
  /// A getter (not `const`) so it re-resolves after [applyBrand] runs.
  static LinearGradient get headerGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [deepAnchor, heritagePurple],
      );

  /// Gradient used on FAB and accent buttons.
  static LinearGradient get fabGradient => LinearGradient(
        colors: [riverFlow, heritagePurple],
      );

  /// Pushes a brand palette from the admin panel into the live palette.
  ///
  /// [brand] drives the purple family — header gradient, FAB, accents, sheets —
  /// and its mid / anchor shades are derived from it so the family stays
  /// coherent no matter which hue is picked. [accent] (optional) drives the
  /// Material "primary" controls (links, focused inputs, default buttons),
  /// which the light theme maps to [milaorBlue].
  static void applyBrand(Color brand, {Color? accent}) {
    heritagePurple = brand;
    riverFlow = shift(brand, 0.10);
    deepAnchor = shift(brand, -0.24);
    if (accent != null) milaorBlue = accent;
  }

  /// Returns [c] lightened (+) or darkened (−) by [delta] in HSL space.
  static Color shift(Color c, double delta) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
  }

  // --- Semantic (mode-independent) ---
  static const Color success      = philippineGreen;
  static const Color successAlt   = Color(0xFF16A34A); // brighter green (status chips)
  static const Color warning      = Color(0xFFFFC107);
  static const Color warningAlt   = Color(0xFFF59E0B); // amber (alert chips)
  static const Color error        = Color(0xFFDC3545);
  static const Color errorAlt     = Color(0xFFEF4444); // bright red (danger labels)
  static const Color errorDark    = Color(0xFFD32F2F); // deep red (logout button)
  static const Color info         = Color(0xFF17A2B8);
  static const Color infoAlt      = Color(0xFF3B82F6); // bright blue (status chips)

  // --- Neutral palette (shared across themes) ---
  static const Color neutralWhite  = Color(0xFFFFFFFF);
  static const Color neutralBlack  = Color(0xFF000000);
  static const Color neutralGray200 = Color(0xFFE9ECEF); // borders, dividers
  static const Color neutralGray500 = Color(0xFF6C757D); // muted / placeholder text
  static const Color neutralGray800 = Color(0xFF343A40); // body text (light mode)

  /// Lavender wash — light-mode scaffold/input canvas used in feature screens
  /// (citizen_report, document_request, hotlines, flood_alert, announcement).
  static const Color warmHearth = Color(0xFFF8F5FF);

  /// Pure white card surface (used as the light-mode card/sheet background).
  static const Color cardWhite  = Color(0xFFFFFFFF);

  // --- Gradient ---
  static LinearGradient get primaryGradient => LinearGradient(
        colors: [milaorBlue, shift(milaorBlue, 0.12)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // --- Mode palettes ---
  static const AppColorScheme light = _LightColors();
  static const AppColorScheme dark  = _DarkColors();

  /// Resolves the correct palette from the current [BuildContext].
  static AppColorScheme of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}

// ── Mode-aware color contract ────────────────────────────────

abstract class AppColorScheme {
  const AppColorScheme();

  // Backgrounds
  Color get background;
  Color get surface;
  Color get cardSurface;

  // Borders & dividers
  Color get border;
  Color get divider;

  // Primary interactive
  Color get primary;
  Color get primaryVariant; // lighter / on-dark adaptation

  // Secondary
  Color get secondary;

  // ── Font / text colors ──────────────────────────────────────
  Color get textPrimary;    // headings, titles
  Color get textSecondary;  // body copy
  Color get textMuted;      // captions, placeholders, hints
  Color get textOnPrimary;  // text sitting ON a primary-color surface
  Color get textLink;       // interactive links / labels
  Color get textError;      // error messages
  Color get textSuccess;    // success messages

  // Icon
  Color get iconPrimary;
  Color get iconMuted;

  // ── Accent purple (mode-aware) ───────────────────────────────
  /// The heritage purple adapted for the current brightness.
  /// Light → heritagePurple; Dark → softer lavender.
  Color get accentPurple;

  // ── Semantic surface shades ──────────────────────────────────
  /// Tinted background for logout / danger zones.
  Color get errorSurface;
  /// Tinted background for success / approved status.
  Color get successSurface;
  /// Tinted background used for form or input areas (light: lavender wash).
  Color get formSurface;
}

// ── Light implementation ─────────────────────────────────────

final class _LightColors extends AppColorScheme {
  const _LightColors();

  @override Color get background    => const Color(0xFFF8F9FA);
  @override Color get surface       => const Color(0xFFFFFFFF);
  @override Color get cardSurface   => const Color(0xFFFFFFFF);

  @override Color get border        => const Color(0xFFE9ECEF);
  @override Color get divider       => const Color(0xFFDEE2E6);

  @override Color get primary       => AppColors.milaorBlue;
  @override Color get primaryVariant => const Color(0xFF0077CC);
  @override Color get secondary     => AppColors.philippineGold;

  // Font colors
  @override Color get textPrimary   => const Color(0xFF212529); // neutralBlack
  @override Color get textSecondary => const Color(0xFF343A40); // neutralGray800
  @override Color get textMuted     => const Color(0xFF6C757D); // neutralGray500
  @override Color get textOnPrimary => const Color(0xFFFFFFFF);
  @override Color get textLink      => AppColors.milaorBlue;
  @override Color get textError     => AppColors.error;
  @override Color get textSuccess   => AppColors.success;

  // Icons
  @override Color get iconPrimary   => AppColors.milaorBlue;
  @override Color get iconMuted     => const Color(0xFF6C757D);

  // Accent purple
  @override Color get accentPurple  => AppColors.heritagePurple;

  // Semantic surfaces
  @override Color get errorSurface   => const Color(0xFFFFF5F5);
  @override Color get successSurface => const Color(0xFFF1F8F3);
  @override Color get formSurface    => const Color(0xFFF6F2FC);
}

// ── Dark implementation ──────────────────────────────────────

final class _DarkColors extends AppColorScheme {
  const _DarkColors();

  @override Color get background    => const Color(0xFF121212);
  @override Color get surface       => const Color(0xFF1E1E1E);
  @override Color get cardSurface   => const Color(0xFF2C2C2C);

  @override Color get border        => const Color(0xFF444444);
  @override Color get divider       => const Color(0xFF333333);

  @override Color get primary       => const Color(0xFF66B5FF); // softened blue
  @override Color get primaryVariant => const Color(0xFF4DA3F0);
  @override Color get secondary     => const Color(0xFFFFD166);

  // Font colors
  @override Color get textPrimary   => const Color(0xFFE9ECEF); // near-white
  @override Color get textSecondary => const Color(0xFFCED4DA); // slightly muted
  @override Color get textMuted     => const Color(0xFF9E9E9E);
  @override Color get textOnPrimary => const Color(0xFF121212); // dark bg on light btn
  @override Color get textLink      => const Color(0xFF66B5FF);
  @override Color get textError     => const Color(0xFFCF6679);
  @override Color get textSuccess   => const Color(0xFF81C784);

  // Icons
  @override Color get iconPrimary   => const Color(0xFF66B5FF);
  @override Color get iconMuted     => const Color(0xFF9E9E9E);

  // Accent purple (softened for dark mode readability) — derived from the live
  // brand color so a customized palette stays legible on dark surfaces.
  @override
  Color get accentPurple => AppColors.shift(AppColors.heritagePurple, 0.24);

  // Semantic surfaces
  @override Color get errorSurface   => const Color(0xFF3D1515);
  @override Color get successSurface => const Color(0xFF1A2E1A);
  @override Color get formSurface    => const Color(0xFF252030);
}