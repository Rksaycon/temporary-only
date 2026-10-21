import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:may_laud/core/local_storage.dart'; // ← ADDED

/// Theme provider for light/dark mode
final themeProvider = StateProvider<bool>((ref) {
  // Default to light mode
  return false;
});

/// App settings provider
class AppSettings {
  final bool isDarkMode;
  final String language;
  final bool notificationsEnabled;
  final bool locationEnabled;

  const AppSettings({
    this.isDarkMode = false,
    this.language = 'en',
    this.notificationsEnabled = true,
    this.locationEnabled = true,
  });

  AppSettings copyWith({
    bool? isDarkMode,
    String? language,
    bool? notificationsEnabled,
    bool? locationEnabled,
  }) {
    return AppSettings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      locationEnabled: locationEnabled ?? this.locationEnabled,
    );
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (ref) => AppSettingsNotifier(),
);

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    _loadSavedSettings(); // ← ADDED: load persisted settings on startup
  }

  // ← ADDED: reads saved dark mode from SharedPreferences
  void _loadSavedSettings() {
    final savedDark = LocalStorage.isDarkMode();
    state = state.copyWith(isDarkMode: savedDark);
  }

  void toggleDarkMode() {
    state = state.copyWith(isDarkMode: !state.isDarkMode);
  }

  void setLanguage(String language) {
    state = state.copyWith(language: language);
  }

  void toggleNotifications() {
    state = state.copyWith(notificationsEnabled: !state.notificationsEnabled);
  }

  void toggleLocation() {
    state = state.copyWith(locationEnabled: !state.locationEnabled);
  }
}

/// Bottom navigation provider
final bottomNavProvider = StateProvider<int>((ref) => 0);

/// Floating action button visibility provider
final fabVisibilityProvider = StateProvider<bool>((ref) => true);