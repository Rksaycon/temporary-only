import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static bool _initialized = false;

  /// app.env is gitignored, so a fresh checkout (and CI) has only the
  /// template. Treat empty values and the shipped placeholder strings as
  /// "not configured" so the app never points at a non-existent project.
  static bool _isRealConfig(String? url, String? key) {
    if (url == null || url.trim().isEmpty) return false;
    if (key == null || key.trim().isEmpty) return false;
    if (url.toLowerCase().contains('placeholder')) return false;
    if (key.toLowerCase().contains('placeholder')) return false;
    return true;
  }

  static Future<void> init() async {
    if (_initialized) return;

    // On web hot reload Supabase may already be initialized — check first
    try {
      Supabase.instance.client;
      _initialized = true;
      return;
    } catch (_) {
      // Not yet initialized, proceed normally
    }

    // FIX — pubspec.yaml lists `app.env` as an asset, so a missing file used
    // to make dotenv.load() throw here. main.dart catches that, which meant
    // the app silently ran with Supabase uninitialized: every sign-in,
    // report, announcement and document-request call then failed with a
    // confusing generic error and no clue why. Load defensively and say
    // exactly what's wrong instead.
    try {
      // Was ".env" — see note in pubspec.yaml (dotfiles get stripped by
      // some static hosts, so the asset was renamed to app.env).
      await dotenv.load(fileName: "app.env");
    } catch (e) {
      debugPrint(
        '[SupabaseService] app.env not found — Supabase is DISABLED. '
        'Copy .env.example to app.env and fill in SUPABASE_URL and '
        'SUPABASE_ANON_KEY. ($e)',
      );
      return;
    }

    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (!_isRealConfig(url, anonKey)) {
      debugPrint(
        '[SupabaseService] app.env is missing real values — Supabase is '
        'DISABLED. Set SUPABASE_URL and SUPABASE_ANON_KEY to your own '
        'project values (see .env.example).',
      );
      return;
    }

    await Supabase.initialize(url: url!, anonKey: anonKey!);
    _initialized = true;
  }

  /// Throws with an actionable message when Supabase isn't configured, so a
  /// misconfigured environment is obvious instead of surfacing later as a
  /// generic network/auth failure. Callers already guard this access
  /// (see NotificationsProvider / DocumentRequestsProvider).
  static SupabaseClient get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError(
        'Supabase is not initialized. Ensure app.env exists and contains a '
        'valid SUPABASE_URL and SUPABASE_ANON_KEY (see .env.example).',
      );
    }
  }

  static User? get currentUser => client.auth.currentUser;
  static String? get userId => currentUser?.id;
}