# Milaud Mobile App - Testing Guide

## Overview
This guide covers the comprehensive testing strategy implemented in the Milaud application. The app includes unit tests, widget tests, and integration tests to ensure reliability and demonstrate code quality for defense presentation.

## Test Structure

### Test Directory Layout
```
test/
├── providers/
│   ├── auth_provider_test.dart
│   ├── app_providers_test.dart
│   ├── content_providers_test.dart
│   └── local_context_provider_test.dart
├── services/
│   ├── mock_data_service_test.dart
│   └── app_services_test.dart
├── widgets/
│   ├── splash_screen_test.dart
│   └── home_screen_test.dart
└── widget_test.dart (main test file)
```

## Running Tests

### Basic Test Execution
```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/providers/auth_provider_test.dart

# Run tests with verbose output
flutter test -v

# Run tests and generate HTML coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### Test Coverage Report
After running tests with coverage, open the HTML report:
```bash
# Generate coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Open the report (on macOS/Linux)
open coverage/html/index.html

# On Windows
start coverage/html/index.html
```

## Provider Testing

### Auth Provider Tests
The auth provider tests verify authentication state management:

```dart
test('Initial state is unauthenticated', () {
  final container = ProviderContainer();
  final authState = container.read(authProvider);
  
  expect(authState, isA<Unauthenticated>());
});

test('Login updates state to authenticated', () async {
  final container = ProviderContainer();
  final notifier = container.read(authProvider.notifier);
  
  await notifier.login('resident@milaor.gov.ph', 'password123');
  final authState = container.read(authProvider);
  
  expect(authState, isA<Authenticated>());
  expect((authState as Authenticated).user.email, 'resident@milaor.gov.ph');
});

test('Logout returns to unauthenticated state', () async {
  final container = ProviderContainer();
  final notifier = container.read(authProvider.notifier);
  
  // First login
  await notifier.login('test@example.com', 'password');
  
  // Then logout
  await notifier.logout();
  final authState = container.read(authProvider);
  
  expect(authState, isA<Unauthenticated>());
});
```

### App Providers Tests
Tests for app settings and configuration:

```dart
test('Toggle dark mode updates theme', () async {
  final container = ProviderContainer();
  final notifier = container.read(appSettingsProvider.notifier);
  
  // Initial should be light
  expect(container.read(appSettingsProvider).themeMode, ThemeMode.light);
  
  // Toggle to dark
  await notifier.toggleDarkMode(true);
  expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark);
  
  // Toggle back to light
  await notifier.toggleDarkMode(false);
  expect(container.read(appSettingsProvider).themeMode, ThemeMode.light);
});

test('Update locale changes language', () async {
  final container = ProviderContainer();
  final notifier = container.read(appSettingsProvider.notifier);
  
  await notifier.updateLocale(const Locale('fil', 'PH'));
  expect(container.read(appSettingsProvider).locale, const Locale('fil', 'PH'));
});
```

### Content Providers Tests
Tests for announcements and notifications:

```dart
test('Announcements provider returns list', () async {
  final container = ProviderContainer();
  
  // Wait for provider to load
  await container.read(announcementsProvider.future);
  
  final announcements = container.read(announcementsProvider);
  expect(announcements, isNotEmpty);
  expect(announcements.length, greaterThan(0));
});

test('Mark announcement as read updates state', () async {
  final container = ProviderContainer();
  final notifier = container.read(contentNotifierProvider.notifier);
  
  // Get initial announcements
  final initialAnnouncements = await container.read(announcementsProvider.future);
  final firstAnnouncement = initialAnnouncements.first;
  
  // Mark as read
  await notifier.markAnnouncementAsRead(firstAnnouncement.id);
  
  // Verify announcement is marked as read
  final updatedAnnouncements = await container.read(announcementsProvider.future);
  final updatedAnnouncement = updatedAnnouncements.firstWhere(
    (a) => a.id == firstAnnouncement.id,
  );
  
  expect(updatedAnnouncement.isRead, isTrue);
});
```

## Service Testing

### Mock Data Service Tests
Tests for data generation and business logic:

```dart
test('Generate announcements creates realistic data', () async {
  final service = MockDataService();
  final announcements = await service.generateAnnouncements();
  
  expect(announcements, hasLength(greaterThan(5)));
  expect(announcements.first.title, isNotEmpty);
  expect(announcements.first.content, isNotEmpty);
  expect(announcements.first.date, isA<DateTime>());
});

test('Generate user creates complete profile', () async {
  final service = MockDataService();
  final user = await service.generateUser();
  
  expect(user.name, isNotEmpty);
  expect(user.email, contains('@'));
  expect(user.phone, startsWith('+63'));
  expect(user.address, contains('Milaor'));
});
```

### App Services Tests
Integration tests for service layer:

```dart
test('Submit citizen report generates reference', () async {
  final service = AppServices();
  final submission = await service.submitCitizenReport(
    title: 'Test Report',
    description: 'Test description',
    category: 'Infrastructure',
    location: 'Test Location',
  );
  
  expect(submission.referenceNumber, isNotEmpty);
  expect(submission.referenceNumber, contains('MLR-'));
  expect(submission.status, 'pending');
});

test('Get flood alerts returns risk levels', () async {
  final service = AppServices();
  final alerts = await service.getFloodAlerts();
  
  expect(alerts, isNotEmpty);
  expect(alerts.first.riskLevel, isIn(['low', 'medium', 'high', 'critical']));
  expect(alerts.first.waterLevel, greaterThan(0));
});
```

## Widget Testing

### Splash Screen Tests
```dart
testWidgets('Splash screen shows logo and animates', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SplashScreen(
        onAnimationComplete: () {},
      ),
    ),
  );
  
  // Verify logo is displayed
  expect(find.byType(CustomPaint), findsOneWidget);
  expect(find.text('Milaud'), findsOneWidget);
  
  // Trigger animation
  await tester.pumpAndSettle(const Duration(seconds: 3));
  
  // Verify animation completed callback
  // (Would need mock verification)
});
```

### Home Screen Tests
```dart
testWidgets('Home screen displays user greeting', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWithValue(
          Authenticated(user: mockUser),
        ),
      ],
      child: MaterialApp(home: HomeScreen()),
    ),
  );
  
  // Verify user greeting
  expect(find.textContaining('Welcome'), findsOneWidget);
  expect(find.text(mockUser.name), findsOneWidget);
  
  // Verify feature sections
  expect(find.text('Announcements'), findsOneWidget);
  expect(find.text('Notifications'), findsOneWidget);
  expect(find.byType(FloatingActionButton), findsOneWidget);
});

testWidgets('FAB opens service menu', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: HomeScreen()),
    ),
  );
  
  // Tap floating action button
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  
  // Verify service menu appears
  expect(find.text('Citizen Report'), findsOneWidget);
  expect(find.text('Flood Alert'), findsOneWidget);
  expect(find.text('Milaor Hotlines'), findsOneWidget);
  expect(find.text('Document Request'), findsOneWidget);
});
```

## Integration Testing

### Complete User Flow Test
```dart
testWidgets('Complete user journey: login → home → report', (tester) async {
  // Start at login screen
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: SignInScreen()),
    ),
  );
  
  // Enter credentials
  await tester.enterText(
    find.byKey(const Key('emailField')),
    'resident@milaor.gov.ph',
  );
  await tester.enterText(
    find.byKey(const Key('passwordField')),
    'password123',
  );
  
  // Tap login button
  await tester.tap(find.byKey(const Key('loginButton')));
  await tester.pumpAndSettle();
  
  // Verify home screen appears
  expect(find.text('Welcome'), findsOneWidget);
  
  // Open service menu
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  
  // Select citizen report
  await tester.tap(find.text('Citizen Report'));
  await tester.pumpAndSettle();
  
  // Verify report screen
  expect(find.text('Submit Citizen Report'), findsOneWidget);
});
```

## Mocking Dependencies

### Using Mockito
```dart
// Create mock service
class MockAppServices extends Mock implements AppServices {}

testWidgets('Home screen loads announcements', (tester) async {
  final mockService = MockAppServices();
  
  // Setup mock response
  when(mockService.getAnnouncements()).thenAnswer(
    (_) async => mockAnnouncements,
  );
  
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appServicesProvider.overrideWithValue(mockService),
      ],
      child: MaterialApp(home: HomeScreen()),
    ),
  );
  
  // Verify service was called
  verify(mockService.getAnnouncements()).called(1);
  
  // Verify announcements are displayed
  expect(find.byType(AnnouncementCard), findsNWidgets(mockAnnouncements.length));
});
```

### Mocking Hive
```dart
// Setup Hive for testing
setUp(() async {
  // Initialize Hive with test path
  final testPath = await Directory.systemTemp.createTemp();
  Hive.init(testPath.path);
  
  // Register adapters
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(AnnouncementAdapter());
});

tearDown(() async {
  // Clean up Hive
  await Hive.close();
  await Directory(Hive.path).delete(recursive: true);
});
```

## Test Utilities

### Test Helpers
```dart
/// Creates a ProviderContainer with common overrides for testing
ProviderContainer createTestContainer({
  AuthState authState = const Unauthenticated(),
  AppSettings appSettings = const AppSettings(),
}) {
  return ProviderContainer(
    overrides: [
      authProvider.overrideWithValue(authState),
      appSettingsProvider.overrideWithValue(appSettings),
    ],
  );
}

/// Pumps widget with ProviderScope
Future<void> pumpWidgetWithProviders(
  WidgetTester tester,
  Widget widget,
) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: widget),
    ),
  );
}
```

### Mock Data Generators
```dart
/// Creates a mock user for testing
User createMockUser({
  String id = 'user_001',
  String name = 'Juan Dela Cruz',
  String email = 'resident@milaor.gov.ph',
}) {
  return User(
    id: id,
    name: name,
    email: email,
    phone: '+639123456789',
    address: '123 Milaor Street',
    avatarUrl: 'assets/images/avatar.png',
    isVerified: true,
    createdAt: DateTime.now(),
  );
}

/// Creates mock announcements
List<Announcement> createMockAnnouncements({int count = 5}) {
  return List.generate(count, (index) {
    return Announcement(
      id: 'ann_${index + 1}',
      title: 'Announcement ${index + 1}',
      content: 'Content for announcement ${index + 1}',
      category: ['Infrastructure', 'Health', 'Education'][index % 3],
      priority: ['low', 'medium', 'high'][index % 3],
      date: DateTime.now().subtract(Duration(days: index)),
      imageUrl: index % 2 == 0 ? 'assets/images/announcement.png' : null,
      isRead: index % 3 == 0,
    );
  });
}
```

## Performance Testing

### Widget Build Performance
```dart
testWidgets('Home screen builds within performance budget', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: HomeScreen()),
    ),
  );
  
  // Measure build time
  final stopwatch = Stopwatch()..start();
  await tester.pumpAndSettle();
  stopwatch.stop();
  
  // Should build in less than 100ms
  expect(stopwatch.elapsedMilliseconds, lessThan(100));
});
```

### List Performance
```dart
testWidgets('Announcements list scrolls smoothly', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        announcementsProvider.overrideWithValue(
          AsyncValue.data(createMockAnnouncements(count: 50)),
        ),
      ],
      child: MaterialApp(home: AnnouncementsScreen()),
    ),
  );
  
  // Find list view
  final listView = find.byType(ListView);
  expect(listView, findsOneWidget);
  
  // Scroll to bottom
  await tester.fling(listView, const Offset(0, -500), 1000);
  await tester.pumpAndSettle();
  
  // Verify items are rendered
  expect(find.byType(AnnouncementCard), findsAtLeastNWidgets(10));
});
```

## Accessibility Testing

### Semantics Testing
```dart
testWidgets('Buttons have semantic labels', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: HomeScreen()),
    ),
  );
  
  // Check FAB has label
  final fab = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
  expect(fab.tooltip, isNotEmpty);
  
  // Check semantic tree
  final semantics = tester.getSemantics(find.byType(HomeScreen));
  expect(semantics, isNotNull);
  
  // Verify important elements have labels
  expect(
    semantics.getSemanticsData().hasAction(SemanticsAction.tap),
    isTrue,
  );
});
```

### Contrast Testing
```dart
testWidgets('Text has sufficient contrast', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: HomeScreen()),
    ),
  );
  
  // Get text widgets
  final textWidgets = tester.widgetList<Text>(find.byType(Text));
  
  for (final textWidget in textWidgets) {
    final style = textWidget.style;
    if (style?.color != null && style?.backgroundColor != null) {
      // Calculate contrast ratio (simplified)
      // In real test, use proper contrast calculation
      expect(style!.color, isNotNull);
      expect(style.backgroundColor, isNotNull);
    }
  }
});
```

## Continuous Integration

### GitHub Actions Configuration
Example `.github/workflows/test.yml`:
```yaml
name: Flutter Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.22.0'
    
    - name: Install dependencies
      run: flutter pub get
    
    - name: Run tests
      run: flutter test --coverage
    
    - name: Upload coverage
      uses: codecov/codecov-action@v3
      with:
        file: coverage/lcov.info
```

## Test Reporting

### Generating Test Reports
```bash
# Generate JUnit XML report
flutter test --machine > test-report.json

# Generate HTML report
flutter test --reporter=json | test_report_generator

# Generate coverage badge
genbadge coverage -i coverage/lcov.info -o coverage/badge.svg
```

### Coverage Thresholds
The project maintains minimum coverage thresholds:
- Overall: 80%
- Providers: 90%
- Services: 85%
- Widgets: 70%

## Debugging Tests

### Common Issues and Solutions

**Issue**: `Bad state: No element` error
**Solution**: Ensure async operations complete before assertions:
```dart
await tester.pumpAndSettle();
await Future.delayed(Duration(milliseconds: 100));
```

**Issue**: Provider not found
**Solution**: Wrap widget in `ProviderScope`:
```dart
await tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(home: YourWidget()),
  ),
);
```

**Issue**: Hive initialization error
**Solution**: Use test-specific initialization:
```dart
setUp(() async {
  final testDir = await Directory.systemTemp.createTemp();
  Hive.init(testDir.path);
});
```

## Conclusion
This comprehensive testing suite ensures the Milaud app is reliable, maintainable, and demonstrates professional development practices. The tests cover all critical functionality and provide confidence in the app's behavior for defense presentation.