# Milaud Mobile App - Developer Guide

## Overview
Milaud is a Flutter-based mobile application designed for Milaor residents to enhance participatory governance through digital services. The app provides announcements, notifications, citizen reporting, flood alerts, hotlines, and document requests.

## Architecture

### Tech Stack
- **Framework**: Flutter 3.22.0 (Dart 3.4.0)
- **State Management**: Riverpod 2.4.9
- **Local Storage**: Hive 3.1.5 + shared_preferences 2.2.2
- **UI Framework**: Material 3 with custom Milaor theme
- **Testing**: flutter_test with mockito

### Project Structure
```
lib/
├── core/                    # Core utilities
│   ├── accessibility.dart
│   ├── error_handling.dart
│   ├── local_storage.dart
│   ├── performance_optimization.dart
│   └── responsive.dart
├── providers/              # Riverpod providers
│   ├── auth_provider.dart
│   ├── app_providers.dart
│   ├── content_providers.dart
│   └── local_context_provider.dart
├── services/               # Business logic
│   ├── app_services.dart
│   └── mock_data_service.dart
├── screens/                # UI screens
│   ├── splash_screen.dart
│   ├── main_app.dart
│   ├── signin__signup_screen.dart
│   ├── notifications_screen.dart
│   └── profile_screen.dart
├── theme/                  # Design system
│   └── app_theme.dart
└── main.dart              # App entry point
```

## State Management with Riverpod

### Provider Types
1. **AuthProvider**: Manages user authentication state
   ```dart
   final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
     return AuthNotifier();
   });
   ```

2. **AppProviders**: Manages app settings (theme, locale, etc.)
   ```dart
   final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
     return AppSettingsNotifier();
   });
   ```

3. **ContentProviders**: Manages announcements and notifications
   ```dart
   final announcementsProvider = FutureProvider<List<Announcement>>((ref) async {
     final service = ref.watch(appServicesProvider);
     return await service.getAnnouncements();
   });
   ```

### Provider Consumption
```dart
class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final announcements = ref.watch(announcementsProvider);
    
    return Scaffold(
      // Widget implementation
    );
  }
}
```

## Data Layer

### Local Storage
The app uses two layers of local storage:
1. **SharedPreferences**: For simple key-value pairs (theme preference, user settings)
2. **Hive**: For structured data (user profiles, cached announcements)

### Mock Data Service
Since the app doesn't require a backend for defense presentation, all data is generated locally:
```dart
class MockDataService {
  Future<List<Announcement>> generateAnnouncements() async {
    // Generates realistic mock announcements
  }
  
  Future<List<Notification>> generateNotifications() async {
    // Generates mock notifications
  }
}
```

## UI/UX Design System

### Milaor Color Palette
The app uses a custom color palette inspired by Milaor's identity:
- **Primary**: `#1A5D1A` (Milaor Green)
- **Secondary**: `#F4A261` (Warm Orange)
- **Accent**: `#2A9D8F` (Teal)
- **Background**: `#F8F9FA` (Light Gray)

### Typography Scale
- **Display Large**: 57px (Roboto)
- **Headline Medium**: 28px (Roboto)
- **Body Large**: 16px (Roboto)
- **Label Small**: 11px (Roboto)

### Responsive Design
The app uses `flutter_screenutil` for responsive layouts:
```dart
ScreenUtil.init(context, designSize: Size(360, 800));
Text(
  'Welcome',
  style: TextStyle(fontSize: 16.sp),
);
```

## Performance Optimization

### Image Caching
```dart
// Configure image cache
PerformanceOptimization.configureImageCache(maxSizeMB: 200);

// Use cached network images
CachedNetworkImage(
  imageUrl: 'https://example.com/image.jpg',
  placeholder: (context, url) => ShimmerEffect(),
  errorWidget: (context, url, error) => Icon(Icons.error),
);
```

### Lazy Loading
```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ListItem(item: items[index]);
  },
);
```

### Debounce and Throttle
```dart
final debouncedSearch = Debouncer(delay: Duration(milliseconds: 500));
debouncedSearch.run(() {
  // Perform search operation
});
```

## Error Handling

### Global Error Catcher
```dart
ErrorWidget.builder = (FlutterErrorDetails details) {
  return CustomErrorWidget(details.exception);
};
```

### AsyncValue Extension
```dart
extension AsyncValueUI<T> on AsyncValue<T> {
  Widget whenWithDefault({
    required Widget Function(T data) data,
    Widget Function()? loading,
    Widget Function(Object error, StackTrace stackTrace)? error,
  }) {
    // Simplified error handling
  }
}
```

## Testing Strategy

### Unit Tests
- Provider tests in `test/providers/`
- Service tests for mock data generation
- Utility function tests

### Widget Tests
- Screen widget tests
- Component tests

### Running Tests
```bash
flutter test
flutter test --coverage
```

## Building and Deployment

### Android Build
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS Build
```bash
flutter build ios --release
```

### Web Build
```bash
flutter build web --release
```

## Code Quality

### Analysis Options
The project uses strict analysis rules defined in `analysis_options.yaml`:
- Enforces null safety
- Requires documentation for public APIs
- Prevents common Dart pitfalls

### Formatting
```bash
flutter format lib/
```

### Linting
```bash
flutter analyze
```

## Development Workflow

### 1. Clone the Repository
```bash
git clone <repository-url>
cd may_laud
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run Development Server
```bash
flutter run
```

### 4. Run Tests
```bash
flutter test
```

### 5. Generate Documentation
```dart
dart doc .
```

## Common Tasks

### Adding a New Screen
1. Create screen file in `lib/screens/`
2. Add route in navigation provider
3. Create corresponding provider if needed
4. Add tests

### Adding a New Provider
1. Create provider file in `lib/providers/`
2. Define state class and notifier
3. Register in `lib/main.dart` ProviderScope
4. Add unit tests

### Adding a New Service
1. Create service file in `lib/services/`
2. Implement business logic
3. Inject dependencies via Riverpod
4. Add integration tests

## Troubleshooting

### Common Issues

1. **Hive not initialized**
   ```dart
   await Hive.initFlutter();
   await Hive.openBox('user_data');
   ```

2. **Riverpod provider not found**
   - Ensure ProviderScope wraps MaterialApp
   - Check provider is defined in correct scope

3. **Image cache issues**
   ```dart
   imageCache.clear();
   imageCache.clearLiveImages();
   ```

4. **Performance problems**
   - Use `PerformanceOptimization.checkMemoryUsage()`
   - Implement lazy loading for lists
   - Optimize image sizes

## Contributing Guidelines

1. Follow Dart style guide
2. Write tests for new features
3. Update documentation
4. Use meaningful commit messages
5. Create PR with clear description

## License
This project is developed for academic purposes as part of a final defense presentation.

## Contact
For technical questions about the implementation, refer to the defense documentation or contact the development team.