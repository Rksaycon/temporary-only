import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:may_laud/providers/app_providers.dart';
import 'package:may_laud/core/local_storage.dart';

// LocalStorage.init() calls Hive.initFlutter(), which asks path_provider
// for the app's documents directory — a real platform channel with no
// implementation in a plain `flutter test` run (MissingPluginException).
// Point it at a throwaway temp directory instead of touching a real
// device/emulator filesystem. (Same helper as auth_provider_test.dart.)
class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String _path =
      Directory.systemTemp.createTempSync('milaud_test_').path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

void main() {
  // FIX — AppSettingsNotifier's constructor reads LocalStorage.isDarkMode()
  // (see _loadSavedSettings() in app_providers.dart), which touches the
  // `static late SharedPreferences _prefs` field. Without LocalStorage.init()
  // every test in this file died with
  //   LateInitializationError: Field '_prefs' has not been initialized.
  // The real app initializes storage in main() before the first widget
  // build; mirror that here.
  setUp(() async {
    PathProviderPlatform.instance = _FakePathProviderPlatform();
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('AppSettingsNotifier Tests', () {
    late ProviderContainer container;
    late AppSettingsNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = AppSettingsNotifier();
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state should have default values', () {
      expect(notifier.state.isDarkMode, false);
      expect(notifier.state.language, 'en');
      expect(notifier.state.notificationsEnabled, true);
      expect(notifier.state.locationEnabled, true);
    });

    test('toggleDarkMode should switch dark mode state', () {
      // Initial state
      expect(notifier.state.isDarkMode, false);

      // First toggle
      notifier.toggleDarkMode();
      expect(notifier.state.isDarkMode, true);

      // Second toggle
      notifier.toggleDarkMode();
      expect(notifier.state.isDarkMode, false);
    });

    test('setLanguage should update language', () {
      expect(notifier.state.language, 'en');

      notifier.setLanguage('fil');
      expect(notifier.state.language, 'fil');

      notifier.setLanguage('es');
      expect(notifier.state.language, 'es');
    });

    test('toggleNotifications should switch notifications state', () {
      // Initial state
      expect(notifier.state.notificationsEnabled, true);

      // First toggle
      notifier.toggleNotifications();
      expect(notifier.state.notificationsEnabled, false);

      // Second toggle
      notifier.toggleNotifications();
      expect(notifier.state.notificationsEnabled, true);
    });

    test('toggleLocation should switch location state', () {
      // Initial state
      expect(notifier.state.locationEnabled, true);

      // First toggle
      notifier.toggleLocation();
      expect(notifier.state.locationEnabled, false);

      // Second toggle
      notifier.toggleLocation();
      expect(notifier.state.locationEnabled, true);
    });

    test('copyWith should create new instance with updated values', () {
      final original = const AppSettings();
      expect(original.isDarkMode, false);
      expect(original.language, 'en');

      final updated = original.copyWith(
        isDarkMode: true,
        language: 'fil',
        notificationsEnabled: false,
      );

      expect(updated.isDarkMode, true);
      expect(updated.language, 'fil');
      expect(updated.notificationsEnabled, false);
      // locationEnabled should remain unchanged
      expect(updated.locationEnabled, true);
    });
  });

  group('Provider Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('themeProvider should have initial value false', () {
      final theme = container.read(themeProvider);
      expect(theme, false);
    });

    test('themeProvider can be updated', () {
      final notifier = container.read(themeProvider.notifier);
      expect(notifier.state, false);

      notifier.state = true;
      expect(notifier.state, true);

      notifier.state = false;
      expect(notifier.state, false);
    });

    test('appSettingsProvider should provide AppSettingsNotifier', () {
      final settings = container.read(appSettingsProvider);
      expect(settings.isDarkMode, false);
      expect(settings.language, 'en');
      expect(settings.notificationsEnabled, true);
      expect(settings.locationEnabled, true);
    });

    test('appSettingsProvider can toggle dark mode', () {
      final notifier = container.read(appSettingsProvider.notifier);
      expect(notifier.state.isDarkMode, false);

      notifier.toggleDarkMode();
      expect(notifier.state.isDarkMode, true);

      notifier.toggleDarkMode();
      expect(notifier.state.isDarkMode, false);
    });

    test('bottomNavProvider should have initial value 0', () {
      final navIndex = container.read(bottomNavProvider);
      expect(navIndex, 0);
    });

    test('bottomNavProvider can be updated', () {
      final notifier = container.read(bottomNavProvider.notifier);
      expect(notifier.state, 0);

      notifier.state = 1;
      expect(notifier.state, 1);

      notifier.state = 2;
      expect(notifier.state, 2);
    });

    test('fabVisibilityProvider should have initial value true', () {
      final fabVisible = container.read(fabVisibilityProvider);
      expect(fabVisible, true);
    });

    test('fabVisibilityProvider can be updated', () {
      final notifier = container.read(fabVisibilityProvider.notifier);
      expect(notifier.state, true);

      notifier.state = false;
      expect(notifier.state, false);

      notifier.state = true;
      expect(notifier.state, true);
    });
  });
}
