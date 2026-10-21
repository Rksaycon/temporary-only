# Milaud Mobile App - API Documentation

## Overview
This document describes the mock API layer used in the Milaud application. Since the app is designed for defense presentation without backend dependencies, all API calls are simulated using the `MockDataService` and `AppServices` classes.

## Mock API Architecture

### Service Layer Structure
```
lib/services/
├── mock_data_service.dart  # Data generation utilities
└── app_services.dart       # Service classes with mock implementations
```

### Data Flow
```
UI Widget → Riverpod Provider → AppService → MockDataService → Local Storage
```

## Service Endpoints

### Authentication Service

#### Login
```dart
Future<User> login(String email, String password)
```
**Mock Response**:
```json
{
  "id": "user_001",
  "name": "Juan Dela Cruz",
  "email": "resident@milaor.gov.ph",
  "phone": "+639123456789",
  "address": "123 Milaor Street, Barangay San Francisco",
  "avatarUrl": "assets/images/avatar.png",
  "isVerified": true
}
```

#### Register
```dart
Future<User> register({
  required String name,
  required String email,
  required String password,
  required String phone,
  required String address,
})
```

#### Logout
```dart
Future<void> logout()
```

#### Get Current User
```dart
Future<User?> getCurrentUser()
```

### Announcements Service

#### Get Announcements
```dart
Future<List<Announcement>> getAnnouncements({
  int limit = 20,
  bool refresh = false,
})
```

**Mock Response**:
```json
[
  {
    "id": "ann_001",
    "title": "Road Closure Announcement",
    "content": "Main street will be closed for repairs from March 15-20...",
    "category": "Infrastructure",
    "priority": "high",
    "date": "2024-03-10T08:00:00Z",
    "imageUrl": "assets/images/home_screen/Road_Announcement.png",
    "isRead": false
  }
]
```

#### Get Announcement by ID
```dart
Future<Announcement> getAnnouncementById(String id)
```

#### Mark as Read
```dart
Future<void> markAnnouncementAsRead(String id)
```

### Notifications Service

#### Get Notifications
```dart
Future<List<AppNotification>> getNotifications()
```

**Mock Response**:
```json
[
  {
    "id": "notif_001",
    "title": "Document Ready for Pickup",
    "body": "Your barangay clearance is ready for pickup at the municipal hall.",
    "type": "document",
    "timestamp": "2024-03-10T14:30:00Z",
    "isRead": false,
    "actionUrl": "/documents/clearance_123"
  }
]
```

#### Mark Notification as Read
```dart
Future<void> markNotificationAsRead(String id)
```

#### Clear All Notifications
```dart
Future<void> clearAllNotifications()
```

### Citizen Report Service

#### Submit Report
```dart
Future<ReportSubmission> submitReport({
  required String title,
  required String description,
  required String category,
  required String location,
  List<String>? imagePaths,
  double? latitude,
  double? longitude,
})
```

**Mock Response**:
```json
{
  "id": "report_001",
  "referenceNumber": "MLR-2024-00123",
  "submittedAt": "2024-03-10T15:45:00Z",
  "status": "pending",
  "estimatedResolutionDays": 7
}
```

#### Get Report Status
```dart
Future<ReportStatus> getReportStatus(String referenceNumber)
```

#### Get User Reports
```dart
Future<List<CitizenReport>> getUserReports()
```

### Flood Alert Service

#### Get Flood Alerts
```dart
Future<List<FloodAlert>> getFloodAlerts()
```

**Mock Response**:
```json
[
  {
    "id": "flood_001",
    "area": "Barangay San Francisco",
    "riskLevel": "medium",
    "waterLevel": "1.2m",
    "trend": "rising",
    "lastUpdated": "2024-03-10T16:00:00Z",
    "advice": "Prepare evacuation kit, monitor updates"
  }
]
```

#### Get Evacuation Centers
```dart
Future<List<EvacuationCenter>> getEvacuationCenters()
```

#### Get Emergency Contacts
```dart
Future<List<EmergencyContact>> getEmergencyContacts()
```

### Hotlines Service

#### Get All Hotlines
```dart
Future<List<Hotline>> getAllHotlines()
```

**Mock Response**:
```json
[
  {
    "id": "hotline_001",
    "department": "Milaor Police Station",
    "phoneNumber": "(054) 123-4567",
    "emergency": true,
    "availableHours": "24/7",
    "description": "For police emergencies and assistance"
  }
]
```

#### Get Hotline by Category
```dart
Future<List<Hotline>> getHotlinesByCategory(String category)
```

### Document Request Service

#### Get Available Documents
```dart
Future<List<DocumentType>> getAvailableDocuments()
```

**Mock Response**:
```json
[
  {
    "id": "doc_001",
    "name": "Barangay Clearance",
    "description": "Certificate of residency for various purposes",
    "fee": 50.0,
    "processingDays": 3,
    "requirements": ["Valid ID", "Proof of residency"]
  }
]
```

#### Submit Document Request
```dart
Future<DocumentRequest> submitDocumentRequest({
  required String documentTypeId,
  required String purpose,
  Map<String, dynamic>? additionalInfo,
})
```

**Mock Response**:
```json
{
  "id": "req_001",
  "referenceNumber": "DOC-2024-00567",
  "documentType": "Barangay Clearance",
  "status": "processing",
  "submittedAt": "2024-03-10T17:00:00Z",
  "estimatedReadyDate": "2024-03-13T17:00:00Z"
}
```

#### Get Request Status
```dart
Future<DocumentRequest> getRequestStatus(String referenceNumber)
```

### Chatbot Service

#### Send Message
```dart
Future<ChatResponse> sendMessage(String message)
```

**Mock Response**:
```json
{
  "id": "chat_001",
  "message": "To get a barangay clearance, you need to visit the barangay hall with a valid ID and proof of residency. The fee is ₱50 and processing takes 3 business days.",
  "timestamp": "2024-03-10T17:30:00Z",
  "suggestions": [
    "Document requirements",
    "Office hours",
    "Contact information"
  ]
}
```

#### Get Chat History
```dart
Future<List<ChatMessage>> getChatHistory()
```

## Data Models

### User Model
```dart
class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String? avatarUrl;
  final bool isVerified;
  final DateTime createdAt;
}
```

### Announcement Model
```dart
class Announcement {
  final String id;
  final String title;
  final String content;
  final String category;
  final String priority; // 'low', 'medium', 'high'
  final DateTime date;
  final String? imageUrl;
  final bool isRead;
}
```

### Notification Model
```dart
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'announcement', 'document', 'report', 'system'
  final DateTime timestamp;
  final bool isRead;
  final String? actionUrl;
}
```

### Citizen Report Model
```dart
class CitizenReport {
  final String id;
  final String title;
  final String description;
  final String category;
  final String status; // 'pending', 'in_progress', 'resolved', 'rejected'
  final DateTime submittedAt;
  final List<String>? imageUrls;
  final String? resolutionNotes;
}
```

### Flood Alert Model
```dart
class FloodAlert {
  final String id;
  final String area;
  final String riskLevel; // 'low', 'medium', 'high', 'critical'
  final double waterLevel;
  final String trend; // 'rising', 'stable', 'falling'
  final DateTime lastUpdated;
  final String advice;
}
```

### Hotline Model
```dart
class Hotline {
  final String id;
  final String department;
  final String phoneNumber;
  final bool emergency;
  final String availableHours;
  final String description;
}
```

### Document Request Model
```dart
class DocumentRequest {
  final String id;
  final String referenceNumber;
  final String documentType;
  final String status; // 'draft', 'submitted', 'processing', 'ready', 'picked_up'
  final DateTime submittedAt;
  final DateTime? estimatedReadyDate;
  final double fee;
}
```

## Error Handling

### Error Types
```dart
enum ApiErrorType {
  networkError,
  serverError,
  authenticationError,
  validationError,
  notFoundError,
  rateLimitError,
  unknownError,
}
```

### Error Response Format
```dart
class ApiError {
  final ApiErrorType type;
  final String message;
  final int? statusCode;
  final DateTime timestamp;
  final Map<String, dynamic>? details;
}
```

### Mock Error Scenarios
The mock service can simulate various error scenarios for testing:

```dart
// Simulate network error
Future<T> simulateNetworkError<T>() async {
  await Future.delayed(Duration(seconds: 2));
  throw ApiError(
    type: ApiErrorType.networkError,
    message: 'No internet connection',
    statusCode: null,
    timestamp: DateTime.now(),
  );
}

// Simulate server error
Future<T> simulateServerError<T>() async {
  await Future.delayed(Duration(seconds: 1));
  throw ApiError(
    type: ApiErrorType.serverError,
    message: 'Internal server error',
    statusCode: 500,
    timestamp: DateTime.now(),
  );
}
```

## Rate Limiting Simulation

The mock service includes rate limiting simulation to demonstrate proper error handling:

```dart
class RateLimiter {
  final int maxRequestsPerMinute;
  final Map<String, List<DateTime>> requestLogs = {};
  
  Future<void> checkRateLimit(String endpoint) async {
    final now = DateTime.now();
    final minuteAgo = now.subtract(Duration(minutes: 1));
    
    final logs = requestLogs[endpoint] ?? [];
    final recentRequests = logs.where((t) => t.isAfter(minuteAgo)).length;
    
    if (recentRequests >= maxRequestsPerMinute) {
      throw ApiError(
        type: ApiErrorType.rateLimitError,
        message: 'Rate limit exceeded. Please try again later.',
        statusCode: 429,
        timestamp: now,
      );
    }
    
    logs.add(now);
    requestLogs[endpoint] = logs;
  }
}
```

## Caching Strategy

### Memory Cache
```dart
class MemoryCache<T> {
  final Map<String, CachedItem<T>> _cache = {};
  final Duration defaultTtl;
  
  Future<T?> get(String key) async {
    final item = _cache[key];
    if (item == null || item.isExpired) {
      return null;
    }
    return item.data;
  }
  
  void set(String key, T data, {Duration? ttl}) {
    _cache[key] = CachedItem(
      data: data,
      expiresAt: DateTime.now().add(ttl ?? defaultTtl),
    );
  }
}
```

### Disk Cache with Hive
```dart
class DiskCache {
  final Box cacheBox;
  
  Future<void> cacheResponse(String endpoint, Map<String, dynamic> data) async {
    await cacheBox.put(endpoint, {
      'data': data,
      'cachedAt': DateTime.now().toIso8601String(),
    });
  }
  
  Future<Map<String, dynamic>?> getCachedResponse(String endpoint) async {
    final cached = cacheBox.get(endpoint);
    if (cached == null) return null;
    
    final cachedAt = DateTime.parse(cached['cachedAt']);
    final age = DateTime.now().difference(cachedAt);
    
    // Return cached data if less than 5 minutes old
    if (age < Duration(minutes: 5)) {
      return cached['data'];
    }
    
    return null;
  }
}
```

## Testing the Mock API

### Unit Tests
```dart
test('Login returns valid user', () async {
  final service = MockDataService();
  final user = await service.login('test@example.com', 'password');
  
  expect(user, isNotNull);
  expect(user.email, 'test@example.com');
  expect(user.isVerified, isTrue);
});

test('Submit report generates reference number', () async {
  final service = MockDataService();
  final submission = await service.submitReport(
    title: 'Pothole on Main Street',
    description: 'Large pothole causing traffic issues',
    category: 'Infrastructure',
    location: 'Main Street, Barangay San Francisco',
  );
  
  expect(submission.referenceNumber, startsWith('MLR-'));
  expect(submission.status, 'pending');
});
```

### Integration Tests
```dart
testWidgets('Complete citizen report flow', (tester) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(home: CitizenReportScreen()),
  ));
  
  // Fill form
  await tester.enterText(find.byType(TextField).first, 'Pothole Report');
  await tester.tap(find.text('Submit'));
  await tester.pumpAndSettle();
  
  // Verify success message
  expect(find.text('Report Submitted'), findsOneWidget);
  expect(find.text('Reference Number:'), findsOneWidget);
});
```

## Future Backend Integration

### Real API Endpoints
When connecting to a real backend, update the service implementations:

```dart
class RealApiService implements AppServices {
  final Dio dio;
  
  @override
  Future<User> login(String email, String password) async {
    final response = await dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    
    return User.fromJson(response.data);
  }
  
  // Other methods implemented with real HTTP calls
}
```

### Environment Configuration
```dart
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.milaor.gov.ph/v1',
  );
  
  static const int timeoutSeconds = 30;
  static const bool enableLogging = bool.fromEnvironment('DEBUG', defaultValue: false);
}
```

## Conclusion
This mock API layer provides a complete simulation of backend services while maintaining the architecture needed for real API integration. The service interfaces are designed to be easily replaceable with HTTP-based implementations when the app transitions to production.