// Tests for the admin-published brand palette (app_theme_provider.dart) and the
// AppColors.applyBrand() plumbing it drives.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:may_laud/providers/app_theme_provider.dart';
import 'package:may_laud/theme/app_colors.dart';

void main() {
  group('AppThemeConfig.fromRow', () {
    test('parses "#RRGGBB" hex from the app_theme row', () {
      final config = AppThemeConfig.fromRow({
        'brand_color': '#4C229C',
        'accent_color': '#0056A3',
      });
      expect(config.brand, const Color(0xFF4C229C));
      expect(config.accent, const Color(0xFF0056A3));
    });

    test('parses hex without the leading #', () {
      final config = AppThemeConfig.fromRow({
        'brand_color': '1D4ED8',
        'accent_color': '0EA5E9',
      });
      expect(config.brand, const Color(0xFF1D4ED8));
      expect(config.accent, const Color(0xFF0EA5E9));
    });

    test('falls back to the defaults for missing or malformed values', () {
      final config = AppThemeConfig.fromRow({
        'brand_color': 'not-a-color',
        'accent_color': null,
      });
      expect(config.brand, AppThemeConfig.defaults.brand);
      expect(config.accent, AppThemeConfig.defaults.accent);
    });
  });

  group('sameColorsAs', () {
    test('is true only when both colours match', () {
      const a = AppThemeConfig(brand: Color(0xFF4C229C), accent: Color(0xFF0056A3));
      const b = AppThemeConfig(brand: Color(0xFF4C229C), accent: Color(0xFF0056A3));
      const c = AppThemeConfig(brand: Color(0xFF1D4ED8), accent: Color(0xFF0056A3));
      expect(a.sameColorsAs(b), isTrue);
      expect(a.sameColorsAs(c), isFalse);
    });
  });

  group('AppColors.applyBrand', () {
    // Reset the shared palette afterwards so one test can't bleed into another.
    void resetPalette() => AppColors.applyBrand(
          AppThemeConfig.defaults.brand,
          accent: AppThemeConfig.defaults.accent,
        );

    test('sets the brand colour and derives the mid / anchor shades', () {
      addTearDown(resetPalette);

      AppColors.applyBrand(const Color(0xFF1D4ED8));

      expect(AppColors.heritagePurple, const Color(0xFF1D4ED8));
      // Derived rather than hard-coded, so any hue stays internally coherent.
      expect(AppColors.riverFlow, isNot(const Color(0xFF1D4ED8)));
      expect(AppColors.deepAnchor, isNot(const Color(0xFF1D4ED8)));
      // The anchor is the darker end of the family.
      expect(
        AppColors.deepAnchor.computeLuminance(),
        lessThan(AppColors.riverFlow.computeLuminance()),
      );
    });

    test('leaves the accent untouched when none is supplied', () {
      addTearDown(resetPalette);

      final before = AppColors.milaorBlue;
      AppColors.applyBrand(const Color(0xFF047857));
      expect(AppColors.milaorBlue, before);
    });

    test('updates the accent when one is supplied', () {
      addTearDown(resetPalette);

      AppColors.applyBrand(
        const Color(0xFF047857),
        accent: const Color(0xFF059669),
      );
      expect(AppColors.milaorBlue, const Color(0xFF059669));
    });

    test('gradients re-resolve against the new palette', () {
      addTearDown(resetPalette);

      AppColors.applyBrand(const Color(0xFFEA580C));
      // headerGradient is [deepAnchor, heritagePurple].
      expect(AppColors.headerGradient.colors.last, AppColors.heritagePurple);
      expect(AppColors.headerGradient.colors.first, AppColors.deepAnchor);
      // fabGradient is [riverFlow, heritagePurple].
      expect(AppColors.fabGradient.colors.first, AppColors.riverFlow);
      expect(AppColors.fabGradient.colors.last, AppColors.heritagePurple);
    });
  });

  group('AppColors.shift', () {
    test('lightening increases lightness', () {
      final base = const Color(0xFF4C229C);
      expect(
        AppColors.shift(base, 0.10).computeLuminance(),
        greaterThan(base.computeLuminance()),
      );
    });

    test('clamps at the ends of the range instead of overflowing', () {
      final light = AppColors.shift(const Color(0xFFFFFFFF), 0.5);
      final dark = AppColors.shift(const Color(0xFF000000), -0.5);
      expect(light.computeLuminance(), closeTo(1.0, 0.001));
      expect(dark.computeLuminance(), closeTo(0.0, 0.001));
    });
  });
}