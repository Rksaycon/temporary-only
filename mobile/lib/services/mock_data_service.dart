import 'dart:math';
import 'package:intl/intl.dart';

/// Mock data service for generating realistic test data
class MockDataService {
  static final Random _random = Random();

  /// Generate mock announcements
  static List<Map<String, dynamic>> generateAnnouncements(int count) {
    final categories = [
      'Community',
      'Infrastructure',
      'Health',
      'Utilities',
      'Government',
      'Events'
    ];
    final titles = [
      'Community Townhall Meeting',
      'Road Closure Notice',
      'Free Vaccination Drive',
      'Water Interruption Schedule',
      'New Business Permit Process',
      'Cultural Festival 2024',
      'Garbage Collection Schedule Update',
      'Power Maintenance Announcement',
      'Scholarship Program Launch',
      'Farmers Market Opening'
    ];

    final descriptions = [
      'Join us for important community discussions and planning sessions.',
      'Please be advised of temporary road closures for maintenance work.',
      'Free health services available for all residents at the municipal health center.',
      'Scheduled maintenance will affect water supply in certain areas.',
      'Streamlined processes now available for business registration.',
      'Celebrate our local culture with traditional performances and food.',
      'Updated schedule for garbage collection in all barangays.',
      'Electrical maintenance will cause temporary power interruptions.',
      'Educational assistance program for qualified students.',
      'Fresh produce and local products available every weekend.'
    ];

    final List<Map<String, dynamic>> announcements = [];
    final now = DateTime.now();

    for (int i = 0; i < count; i++) {
      final daysAgo = _random.nextInt(30);
      final date = now.subtract(Duration(days: daysAgo));

      announcements.add({
        'id': 'ann_${i + 1}',
        'title': titles[_random.nextInt(titles.length)],
        'description': descriptions[_random.nextInt(descriptions.length)],
        'category': categories[_random.nextInt(categories.length)],
        'date': date.toIso8601String(),
        'imageUrl':
            _random.nextBool() ? 'assets/images/announcementimage.png' : null,
        'isImportant': _random.nextDouble() > 0.7,
        'isRead': _random.nextBool(),
      });
    }

    return announcements;
  }

  /// Generate mock notifications
  static List<Map<String, dynamic>> generateNotifications(int count) {
    final types = ['announcement', 'alert', 'reminder', 'system'];
    final titles = [
      'New Announcement',
      'Flood Alert',
      'Document Ready',
      'Report Submitted',
      'Payment Due',
      'Appointment Reminder',
      'System Update',
      'Welcome Message',
      'Security Alert',
      'Community Update'
    ];

    final messages = [
      'A new important announcement has been posted.',
      'Weather alert: Heavy rainfall expected in your area.',
      'Your requested document is ready for pickup.',
      'Your report has been received and is being processed.',
      'Reminder: Payment deadline is approaching.',
      'Don\'t forget your scheduled appointment tomorrow.',
      'System maintenance scheduled for tonight.',
      'Welcome to Milaud! Get started by exploring features.',
      'Unusual login detected on your account.',
      'Latest community news and updates available.'
    ];

    final List<Map<String, dynamic>> notifications = [];
    final now = DateTime.now();

    for (int i = 0; i < count; i++) {
      final hoursAgo = _random.nextInt(168); // Up to 7 days
      final timestamp = now.subtract(Duration(hours: hoursAgo));

      notifications.add({
        'id': 'notif_${i + 1}',
        'title': titles[_random.nextInt(titles.length)],
        'message': messages[_random.nextInt(messages.length)],
        'timestamp': timestamp.toIso8601String(),
        'type': types[_random.nextInt(types.length)],
        'isRead': _random.nextBool(),
      });
    }

    // Sort by timestamp (newest first)
    notifications.sort((a, b) => DateTime.parse(b['timestamp'])
        .compareTo(DateTime.parse(a['timestamp'])));

    return notifications;
  }

  /// Generate mock hotlines/emergency contacts
  static List<Map<String, dynamic>> generateHotlines() {
    return [
      {
        'id': '1',
        'name': 'Milaor Police Station',
        'number': '(054) 123-4567',
        'type': 'police',
        'description': '24/7 emergency police assistance',
        'icon': '🚓',
      },
      {
        'id': '2',
        'name': 'Milaor Fire Station',
        'number': '(054) 123-4568',
        'type': 'fire',
        'description': 'Fire and rescue emergencies',
        'icon': '🚒',
      },
      {
        'id': '3',
        'name': 'Milaor Health Center',
        'number': '(054) 123-4569',
        'type': 'health',
        'description': 'Medical emergencies and consultations',
        'icon': '🏥',
      },
      {
        'id': '4',
        'name': 'Municipal Hall',
        'number': '(054) 123-4570',
        'type': 'government',
        'description': 'Local government inquiries',
        'icon': '🏛️',
      },
      {
        'id': '5',
        'name': 'Disaster Risk Reduction Office',
        'number': '(054) 123-4571',
        'type': 'disaster',
        'description': 'Disaster preparedness and response',
        'icon': '⚠️',
      },
      {
        'id': '6',
        'name': 'Public Works Office',
        'number': '(054) 123-4572',
        'type': 'infrastructure',
        'description': 'Road and infrastructure concerns',
        'icon': '🚧',
      },
      {
        'id': '7',
        'name': 'Water District',
        'number': '(054) 123-4573',
        'type': 'utility',
        'description': 'Water supply and billing inquiries',
        'icon': '💧',
      },
      {
        'id': '8',
        'name': 'Electric Cooperative',
        'number': '(054) 123-4574',
        'type': 'utility',
        'description': 'Power outages and electrical concerns',
        'icon': '⚡',
      },
    ];
  }

  /// Generate mock document types for requests
  static List<Map<String, dynamic>> generateDocumentTypes() {
    return [
      {
        'id': '1',
        'name': 'Barangay Clearance',
        'description': 'Certificate of residency and good moral character',
        'processingTime': '1-2 days',
        'fee': '₱50.00',
        'requirements': [
          'Valid ID',
          'Proof of residency',
          'Barangay registration',
        ],
      },
      {
        'id': '2',
        'name': 'Business Permit',
        'description': 'License to operate a business in Milaor',
        'processingTime': '3-5 days',
        'fee': '₱500.00 - ₱5,000.00',
        'requirements': [
          'DTI/SEC registration',
          'Proof of business address',
          'Mayor\'s permit application form',
        ],
      },
      {
        'id': '3',
        'name': 'Certificate of Indigency',
        'description': 'Proof of low-income status for government assistance',
        'processingTime': '1 day',
        'fee': '₱20.00',
        'requirements': [
          'Valid ID',
          'Proof of income',
          'Barangay certification',
        ],
      },
      {
        'id': '4',
        'name': 'Police Clearance',
        'description': 'Certificate of no criminal record',
        'processingTime': '2-3 days',
        'fee': '₱100.00',
        'requirements': [
          'Valid ID',
          '2x2 photo',
          'Barangay clearance',
        ],
      },
      {
        'id': '5',
        'name': 'Building Permit',
        'description': 'Authorization for construction projects',
        'processingTime': '7-14 days',
        'fee': 'Based on project cost',
        'requirements': [
          'Land title',
          'Building plans',
          'Engineer/Architect\'s certificate',
        ],
      },
    ];
  }

  /// Generate mock flood alert data
  static Map<String, dynamic> generateFloodAlert() {
    final levels = ['Low', 'Moderate', 'High', 'Critical'];
    final level = levels[_random.nextInt(levels.length)];

    final areas = [
      'Barangay San Jose',
      'Barangay San Roque',
      'Barangay San Isidro',
      'Barangay San Miguel',
      'Barangay San Antonio',
    ];

    final affectedAreas = <String>[];
    for (int i = 0; i < _random.nextInt(3) + 1; i++) {
      affectedAreas.add(areas[_random.nextInt(areas.length)]);
    }

    return {
      'level': level,
      'affectedAreas': affectedAreas.toSet().toList(), // Remove duplicates
      'waterLevel': '${_random.nextInt(300) + 50} cm',
      'updateTime': DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.now()),
      'advice': _getFloodAdvice(level),
      'isActive': level == 'High' || level == 'Critical',
    };
  }

  static String _getFloodAdvice(String level) {
    switch (level) {
      case 'Low':
        return 'Monitor weather updates. No immediate action required.';
      case 'Moderate':
        return 'Prepare emergency kits. Stay alert for updates.';
      case 'High':
        return 'Consider evacuation if in low-lying areas. Avoid flooded streets.';
      case 'Critical':
        return 'Evacuate immediately to designated safe zones. Follow authorities\' instructions.';
      default:
        return 'Stay informed through official channels.';
    }
  }

  /// Generate mock citizen report categories
  static List<Map<String, dynamic>> generateReportCategories() {
    return [
      {
        'id': '1',
        'name': 'Infrastructure',
        'icon': '🚧',
        'subcategories': [
          'Road Damage',
          'Bridge Issues',
          'Street Light',
          'Drainage Problems'
        ],
      },
      {
        'id': '2',
        'name': 'Sanitation',
        'icon': '🗑️',
        'subcategories': [
          'Garbage Collection',
          'Illegal Dumping',
          'Public Toilets',
          'Drainage Clogged'
        ],
      },
      {
        'id': '3',
        'name': 'Public Safety',
        'icon': '👮',
        'subcategories': [
          'Criminal Activity',
          'Traffic Violations',
          'Fire Hazards',
          'Stray Animals'
        ],
      },
      {
        'id': '4',
        'name': 'Environment',
        'icon': '🌳',
        'subcategories': [
          'Tree Maintenance',
          'Flooding',
          'Erosion',
          'Pollution'
        ],
      },
      {
        'id': '5',
        'name': 'Utilities',
        'icon': '⚡',
        'subcategories': [
          'Water Supply',
          'Power Outage',
          'Internet Issues',
          'Telephone Lines'
        ],
      },
      {
        'id': '6',
        'name': 'Others',
        'icon': '📋',
        'subcategories': ['General Complaint', 'Suggestion', 'Other Concerns'],
      },
    ];
  }

  /// Generate mock user profile
  static Map<String, dynamic> generateUserProfile() {
    return {
      'id': 'user_001',
      'name': 'Juan Dela Cruz',
      'email': 'juan.delacruz@example.com',
      'phone': '+639123456789',
      'address': '123 San Jose Street, Milaor, Camarines Sur',
      'birthDate': '1985-06-15',
      'profileImage': 'assets/images/avatar.png',
      'memberSince': '2023-01-15',
      'reportsSubmitted': 12,
      'documentsRequested': 5,
      'notificationsEnabled': true,
      'locationEnabled': true,
    };
  }
}
