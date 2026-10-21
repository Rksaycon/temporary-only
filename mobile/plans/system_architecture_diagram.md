# Milaud Mobile App - System Architecture

## Overall Architecture Diagram

```mermaid
graph TB
    subgraph "Presentation Layer"
        UI[UI Screens]
        Widgets[Custom Widgets]
        Components[Reusable Components]
    end
    
    subgraph "State Management Layer"
        AuthProvider[Auth Provider]
        UserProvider[User Provider]
        AnnouncementProvider[Announcement Provider]
        NotificationProvider[Notification Provider]
        ServiceProvider[Service Provider]
    end
    
    subgraph "Business Logic Layer"
        AuthService[Auth Service]
        AnnouncementService[Announcement Service]
        NotificationService[Notification Service]
        ReportService[Report Service]
        LocalizationService[Localization Service]
    end
    
    subgraph "Data Layer"
        APIRepository[API Repository]
        LocalRepository[Local Repository]
        Models[Data Models]
    end
    
    subgraph "External Services"
        MockAPI[Mock API Server]
        RealAPI[Real Backend API]
        LocalDB[Hive Database]
        Prefs[Shared Preferences]
        Assets[Asset Files]
    end
    
    UI --> StateManagementLayer
    Widgets --> StateManagementLayer
    Components --> StateManagementLayer
    
    StateManagementLayer --> BusinessLogicLayer
    BusinessLogicLayer --> DataLayer
    
    DataLayer --> ExternalServices
    
    classDef presentation fill:#e1f5fe,stroke:#01579b
    classDef state fill:#f3e5f5,stroke:#4a148c
    classDef business fill:#e8f5e8,stroke:#1b5e20
    classDef data fill:#fff3e0,stroke:#e65100
    classDef external fill:#fce4ec,stroke:#880e4f
    
    class UI,Widgets,Components presentation
    class AuthProvider,UserProvider,AnnouncementProvider,NotificationProvider,ServiceProvider state
    class AuthService,AnnouncementService,NotificationService,ReportService,LocalizationService business
    class APIRepository,LocalRepository,Models data
    class MockAPI,RealAPI,LocalDB,Prefs,Assets external
```

## Component Interaction Flow

```mermaid
sequenceDiagram
    participant User
    participant UI as UI Screen
    participant Provider as Riverpod Provider
    participant Service as Business Service
    participant Repository as Data Repository
    participant API as API/DB
    
    User->>UI: Performs Action
    UI->>Provider: Notify State Change
    Provider->>Service: Execute Business Logic
    Service->>Repository: Request Data
    Repository->>API: Fetch/Store Data
    API-->>Repository: Return Data
    Repository-->>Service: Processed Data
    Service-->>Provider: Update State
    Provider-->>UI: Rebuild UI
    UI-->>User: Show Updated Interface
```

## Authentication Flow Architecture

```mermaid
graph LR
    subgraph "Authentication Flow"
        A1[Splash Screen]
        A2[Login Screen]
        A3[Registration Screen]
        A4[OTP Verification]
        A5[Forgot Password]
        A6[Main App]
        A7[Session Manager]
    end
    
    subgraph "State Management"
        B1[Auth Provider]
        B2[User Provider]
        B3[Token Manager]
    end
    
    subgraph "Data Layer"
        C1[Auth Repository]
        C2[User Repository]
        C3[Local Storage]
    end
    
    A1 --> A2
    A2 --> A3
    A2 --> A4
    A2 --> A5
    A3 --> A4
    A4 --> A6
    A5 --> A4
    
    A7 --> B1
    B1 --> C1
    C1 --> C3
    
    classDef auth fill:#e1f5fe,stroke:#0277bd
    classDef state fill:#f3e5f5,stroke:#7b1fa2
    classDef data fill:#e8f5e8,stroke:#2e7d32
    
    class A1,A2,A3,A4,A5,A6,A7 auth
    class B1,B2,B3 state
    class C1,C2,C3 data
```

## Data Flow for Citizen Report

```mermaid
graph TD
    subgraph "User Interaction"
        U1[Open Citizen Report]
        U2[Fill Report Form]
        U3[Attach Photos]
        U4[Submit Report]
        U5[View Status]
    end
    
    subgraph "Application Processing"
        P1[Form Validation]
        P2[Image Compression]
        P3[Geolocation Capture]
        P4[Data Serialization]
        P5[Network Request]
        P6[Local Storage]
        P7[Status Tracking]
    end
    
    subgraph "Backend Systems"
        B1[API Endpoint]
        B2[Database]
        B3[Notification Service]
        B4[Admin Dashboard]
    end
    
    U1 --> U2
    U2 --> P1
    U3 --> P2
    P1 --> P3
    P2 --> P4
    P3 --> P4
    P4 --> P5
    P5 --> B1
    B1 --> B2
    B2 --> B3
    B3 --> B4
    
    P4 --> P6
    P6 --> U5
    B1 --> P7
    P7 --> U5
    
    classDef user fill:#fff3e0,stroke:#f57c00
    classDef app fill:#e8f5e8,stroke:#43a047
    classDef backend fill:#fce4ec,stroke:#c2185b
    
    class U1,U2,U3,U4,U5 user
    class P1,P2,P3,P4,P5,P6,P7 app
    class B1,B2,B3,B4 backend
```

## File Structure Organization

```
lib/
├── main.dart
├── theme/                    # Design System
│   ├── app_theme.dart
│   ├── color_palette.dart
│   ├── typography.dart
│   ├── spacing.dart
│   └── shadow.dart
├── providers/               # Riverpod Providers
│   ├── auth_provider.dart
│   ├── user_provider.dart
│   ├── announcement_provider.dart
│   ├── notification_provider.dart
│   └── service_provider.dart
├── services/               # Business Logic
│   ├── api_service.dart
│   ├── auth_service.dart
│   ├── announcement_service.dart
│   ├── notification_service.dart
│   └── report_service.dart
├── repositories/           # Data Access
│   ├── auth_repository.dart
│   ├── announcement_repository.dart
│   ├── user_repository.dart
│   └── local_repository.dart
├── models/                 # Data Models
│   ├── user_model.dart
│   ├── announcement_model.dart
│   ├── notification_model.dart
│   └── report_model.dart
├── screens/               # UI Screens
│   ├── auth/
│   ├── home/
│   ├── announcements/
│   ├── notifications/
│   ├── profile/
│   └── services/
├── components/            # Reusable Widgets
│   ├── buttons/
│   ├── cards/
│   ├── dialogs/
│   ├── loaders/
│   └── empty_states/
├── utils/                 # Utilities
│   ├── validators.dart
│   ├── formatters.dart
│   ├── constants.dart
│   └── helpers.dart
└── data/                  # Static Data
    ├── milaor_data.dart
    ├── barangays.dart
    └── emergency_contacts.dart
```

## Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **UI Framework** | Flutter 3.0+ | Cross-platform mobile development |
| **State Management** | Riverpod 2.0 | Predictable state management |
| **Networking** | Dio 5.0 | HTTP client with interceptors |
| **Local Storage** | Hive 3.0 | NoSQL database for offline data |
| **Preferences** | Shared Preferences 2.0 | Simple key-value storage |
| **Animations** | Flutter Animate 4.0 | Smooth UI animations |
| **Images** | Cached Network Image 3.0 | Image caching and loading |
| **SVG** | Flutter SVG 2.0 | Vector graphics support |
| **Testing** | Flutter Test | Unit and widget testing |
| **Linting** | Flutter Lints 6.0 | Code quality enforcement |

## Key Design Decisions

1. **Riverpod over Provider/Bloc** - Better testability, no BuildContext dependency
2. **Clean Architecture** - Separation of concerns, testable business logic
3. **Mock API First** - Development without backend dependency
4. **Offline-First** - Local storage for all critical data
5. **Accessibility First** - WCAG compliance from start
6. **Material 3** - Modern design system with dynamic color
7. **Responsive Design** - flutter_screenutil for consistent scaling

## Performance Considerations

1. **Image Optimization** - Compress assets, use WebP format
2. **Lazy Loading** - Pagination for lists, deferred image loading
3. **Memory Management** - Dispose controllers, avoid memory leaks
4. **Build Optimization** - Const constructors, extracted widgets
5. **Network Optimization** - Request caching, compression

## Security Measures

1. **Token Storage** - Secure storage with flutter_secure_storage
2. **Input Validation** - Client-side validation for all forms
3. **HTTPS Only** - All API calls over secure connection
4. **Data Encryption** - Sensitive data encryption at rest
5. **Session Management** - Automatic token refresh, logout on expiry

---

*This architecture ensures a scalable, maintainable, and testable codebase that can evolve from a defense presentation project to a production-ready application for Milaor residents.*