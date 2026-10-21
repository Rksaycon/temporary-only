// lib/providers/app_theme_provider.dart
//
// Live brand-color customization. The admin panel's "App Customization" page
// (Maylaud_Web) publishes a brand + accent color to the Supabase `app_theme`
// table (a single row, id = 1). This provider:
//
//   1. loads that row once at launch — main.dart calls AppThemeService.fetch()
//      before runApp, so the very first frame already wears the chosen colors,
//   2. subscribes to Postgres Changes on `app_theme`, and
//   3. applies every change to AppColors and bumps a revision counter.
//
// MyApp watches the revision and remounts itself when it changes. That remount
// is what makes the whole app — including screens that were already built —
// repaint with the new palette; AppColors.* are plain statics, so nothing else
// would rebuild on its own.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:may_laud/services/supabase_service.dart';
import 'package:may_laud/theme/app_colors.dart';

/// The palette the admin panel controls.
class AppThemeConfig {
  final Color brand;
  final Color accent;

  const AppThemeConfig({required this.brand, required this.accent});

  /// The shipped Maylaud palette — also the fallback when Supabase is
  /// unreachable or has no row yet.
  static const AppThemeConfig defaults = AppThemeConfig(
    brand: Color(0xFF4C229C), // heritagePurple
    accent: Color(0xFF0056A3), // milaorBlue
  );

  factory AppThemeConfig.fromRow(Map<String, dynamic> row) {
    return AppThemeConfig(
      brand: _parseHex(row['brand_color']) ?? defaults.brand,
      accent: _parseHex(row['accent_color']) ?? defaults.accent,
    );
  }

  bool sameColorsAs(AppThemeConfig other) =>
      brand == other.brand && accent == other.accent;

  /// Accepts "#RRGGBB" or "RRGGBB" (case-insensitive).
  static Color? _parseHex(Object? value) {
    if (value is! String) return null;
    var hex = value.trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}

/// Holds the palette that is currently applied, so the rest of the app can read
/// it without querying Supabase again.
abstract final class AppThemeService {
  static AppThemeConfig current = AppThemeConfig.defaults;

  /// Fetches the published palette once (called from main() before runApp).
  /// Never throws — falls back to [AppThemeConfig.defaults].
  static Future<AppThemeConfig> fetch() async {
    try {
      final row = await SupabaseService.client
          .from('app_theme')
          .select('brand_color, accent_color')
          .eq('id', 1)
          .maybeSingle();
      if (row != null) current = AppThemeConfig.fromRow(row);
    } catch (e) {
      // PGRST204 / "schema cache" means the table was never created — the app
      // just keeps its built-in palette, so this is expected until an admin runs
      // supabase_app_theme.sql. Worth saying plainly in the logs because the
      // symptom (colours not changing) otherwise looks like a sync bug.
      debugPrint('[AppThemeService] Falling back to the default palette: $e');
      if ('$e'.contains('schema cache') || '$e'.contains('PGRST204')) {
        debugPrint(
          '[AppThemeService] public.app_theme is missing — run '
          'supabase_app_theme.sql in the Supabase SQL Editor to enable '
          'admin colour changes.',
        );
      }
    }
    return current;
  }

  /// Pushes [config] into the live [AppColors] palette.
  static void apply(AppThemeConfig config) {
    current = config;
    AppColors.applyBrand(config.brand, accent: config.accent);
  }
}

/// Increments every time a *post-launch* palette change is applied. MyApp uses
/// it as a widget key so the whole tree rebuilds and repaints.
class AppThemeRevisionNotifier extends StateNotifier<int> {
  AppThemeRevisionNotifier() : super(0) {
    _subscribe();
  }

  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  void _subscribe() {
    try {
      _sub = SupabaseService.client
          .from('app_theme')
          .stream(primaryKey: ['id'])
          .eq('id', 1)
          .listen(
            (rows) {
              if (rows.isEmpty) return;
              final config = AppThemeConfig.fromRow(rows.first);
              if (config.sameColorsAs(AppThemeService.current)) return;
              AppThemeService.apply(config);
              state = state + 1; // → MyApp remounts with the new palette
            },
            onError: (Object e) =>
                debugPrint('[AppThemeRevisionNotifier] stream error: $e'),
          );
    } catch (e) {
      // Supabase not configured (e.g. web without app.env) — the palette
      // applied at launch is all we need.
      debugPrint('[AppThemeRevisionNotifier] realtime skipped: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final appThemeRevisionProvider =
    StateNotifierProvider<AppThemeRevisionNotifier, int>(
      (ref) => AppThemeRevisionNotifier(),
    );
