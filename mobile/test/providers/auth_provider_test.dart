import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:may_laud/providers/auth_provider.dart';
import 'package:may_laud/core/local_storage.dart';

// LocalStorage.init() calls Hive.initFlutter(), which asks path_provider
// for the app's documents directory — a real platform channel with no
// implementation in a plain `flutter test` run (MissingPluginException).
// Point it at a throwaway temp directory instead of touching a real
// device/emulator filesystem.
class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String _path = Directory.systemTemp
      .createTempSync('milaud_test_')
      .path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

// NOTE — this file used to test a fake, fully in-memory auth backend
// (hardcoded 'test@milaor.gov.ph' / 'password123' credentials, immediate
// success/failure, no network) via `AuthProvider()` — a no-arg
// constructor that no longer exists. AuthProvider now talks to a real
// Supabase project (see login()/register() in auth_provider.dart), so
// those scripted success/failure paths were deleted along with it —
// asserting on them here would just be asserting behavior that isn't
// there anymore. This test process never calls Supabase.initialize(),
// so what's left below sticks to what's true regardless of network:
// the state machine's shape (starts clean, never leaves isLoading stuck
// on true) and the pure User model.
void main() {
  group('AuthProvider Tests', () {
    late ProviderContainer container;

    setUp(() async {
      PathProviderPlatform.instance = _FakePathProviderPlatform();
      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
      // Initialize LocalStorage
      await LocalStorage.init();
      // Clear any stored data before each test
      await LocalStorage.clearAll();
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state should be unauthenticated', () {
      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
      expect(state.isLoading, false);
      expect(state.user, null);
      expect(state.error, null);
    });

    test('login() always resolves — never leaves isLoading stuck on true',
        () async {
      final notifier = container.read(authProvider.notifier);

      await notifier.login('someone@example.com', 'whatever');

      // Can't assert authenticated true/false here — that depends on a
      // real Supabase project actually being reachable, which this test
      // process never connects to. What matters is the notifier settles
      // (and reports an error) instead of hanging.
      final state = container.read(authProvider);
      expect(state.isLoading, false);
      expect(state.error, isNotNull);
    });

    test('loginAsGuest should authenticate as a guest user', () async {
      final notifier = container.read(authProvider.notifier);

      await notifier.loginAsGuest();

      final state = container.read(authProvider);
      expect(state.isAuthenticated, true);
      expect(state.isGuest, true);
      expect(state.user, isNotNull);
      expect(state.user!.name, 'Guest User');
    });

    test('logout() resets state back to unauthenticated', () async {
      final notifier = container.read(authProvider.notifier);
      await notifier.loginAsGuest();

      await notifier.logout();

      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
      expect(state.user, null);
      expect(state.isLoading, false);
    });
  });

  group('User Model Tests', () {
    test('User.fromJson should parse valid JSON', () {
      // Arrange — keys match what User.fromJson actually reads: a
      // `profiles` row (avatar_url, created_at, ...), plus `email`
      // merged in separately from the Supabase auth session (see
      // _loadProfile() in auth_provider.dart).
      final json = {
        'id': 'user123',
        'name': 'John Doe',
        'email': 'john@milaor.gov.ph',
        'phone': '09123456789',
        'avatar_url': 'https://example.com/avatar.jpg',
        'address': 'Milaor, Camarines Sur',
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      // Act
      final user = User.fromJson(json);

      // Assert
      expect(user.id, 'user123');
      expect(user.name, 'John Doe');
      expect(user.email, 'john@milaor.gov.ph');
      expect(user.phone, '09123456789');
      expect(user.profileImage, 'https://example.com/avatar.jpg');
      expect(user.address, 'Milaor, Camarines Sur');
      expect(user.createdAt, DateTime.utc(2024, 1, 1));
    });

    test('User.toJson should serialize correctly', () {
      // Arrange
      final user = User(
        id: 'user123',
        name: 'John Doe',
        email: 'john@milaor.gov.ph',
        phone: '09123456789',
        profileImage: 'https://example.com/avatar.jpg',
        address: 'Milaor, Camarines Sur',
        createdAt: DateTime.utc(2024, 1, 1),
      );

      // Act
      final json = user.toJson();

      // Assert — toJson mirrors the `profiles` table's column names, not
      // the Dart field names (see User.toJson in auth_provider.dart).
      expect(json['id'], 'user123');
      expect(json['name'], 'John Doe');
      expect(json['email'], 'john@milaor.gov.ph');
      expect(json['phone'], '09123456789');
      expect(json['avatar_url'], 'https://example.com/avatar.jpg');
      expect(json['address'], 'Milaor, Camarines Sur');
      expect(json['created_at'], '2024-01-01T00:00:00.000Z');
    });
  });
}
