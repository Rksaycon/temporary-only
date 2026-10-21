import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Milaor local context data
class MilaorLocalContext {
  final String municipalityName = 'Milaor';
  final String province = 'Camarines Sur';
  final String region = 'Bicol Region (Region V)';
  final String country = 'Philippines';

  /// Barangays in Milaor
  final List<String> barangays = [
    'San Antonio',
    'San Francisco',
    'San Isidro',
    'San Jose',
    'San Miguel',
    'San Roque',
    'Santa Cruz',
    'Santa Rita',
    'Santo Domingo',
    'Santo Niño',
  ];

  /// Local landmarks
  final List<Map<String, dynamic>> landmarks = [
    {
      'name': 'Milaor Municipal Hall',
      'type': 'government',
      'description': 'Seat of local government',
      'location': 'Poblacion, Milaor',
      'coordinates': {'lat': 13.5961, 'lng': 123.1758},
    },
    {
      'name': 'St. John the Baptist Parish Church',
      'type': 'religious',
      'description': 'Historical Catholic church',
      'location': 'Poblacion, Milaor',
      'coordinates': {'lat': 13.5958, 'lng': 123.1762},
    },
    {
      'name': 'Milaor Public Market',
      'type': 'commercial',
      'description': 'Local market for fresh produce and goods',
      'location': 'Poblacion, Milaor',
      'coordinates': {'lat': 13.5965, 'lng': 123.1770},
    },
    {
      'name': 'Milaor Health Center',
      'type': 'health',
      'description': 'Primary healthcare facility',
      'location': 'San Jose, Milaor',
      'coordinates': {'lat': 13.5970, 'lng': 123.1780},
    },
    {
      'name': 'Milaor Central Elementary School',
      'type': 'education',
      'description': 'Public elementary school',
      'location': 'Poblacion, Milaor',
      'coordinates': {'lat': 13.5950, 'lng': 123.1745},
    },
  ];

  /// Local festivals and events
  final List<Map<String, dynamic>> festivals = [
    {
      'name': 'Pabasa ng Pasyon',
      'month': 'April',
      'description':
          'Traditional chanting of the Passion of Christ during Holy Week',
    },
    {
      'name': 'Feast of St. John the Baptist',
      'month': 'June 24',
      'description': 'Town fiesta honoring the patron saint',
    },
    {
      'name': 'Araw ng Milaor',
      'month': 'December',
      'description': 'Foundation anniversary celebration',
    },
    {
      'name': 'Christmas Lantern Festival',
      'month': 'December',
      'description': 'Annual lantern-making competition and display',
    },
  ];

  /// Local officials (mock data)
  final Map<String, String> localOfficials = {
    'Municipal Mayor': 'Hon. Juan Dela Cruz',
    'Municipal Vice Mayor': 'Hon. Maria Santos',
    'Municipal Councilors': '8 elected councilors',
    'Municipal Administrator': 'Mr. Pedro Reyes',
  };

  /// Local emergency contacts
  final List<Map<String, dynamic>> emergencyContacts = [
    {
      'name': 'Milaor Police Station',
      'number': '(054) 123-4567',
      'type': 'police',
    },
    {
      'name': 'Milaor Fire Station',
      'number': '(054) 123-4568',
      'type': 'fire',
    },
    {
      'name': 'Milaor Health Center',
      'number': '(054) 123-4569',
      'type': 'health',
    },
    {
      'name': 'Municipal Disaster Risk Reduction Office',
      'number': '(054) 123-4570',
      'type': 'disaster',
    },
  ];

  /// Local economy highlights
  final Map<String, dynamic> economy = {
    'primaryIndustries': ['Agriculture', 'Fishing', 'Small-scale Commerce'],
    'mainProducts': ['Rice', 'Coconut', 'Vegetables', 'Fish'],
    'marketDays': ['Tuesday', 'Friday', 'Sunday'],
    'businessHours': '6:00 AM - 8:00 PM',
  };

  /// Get greeting based on time of day
  String getTimeBasedGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Magandang umaga, ka-Milaor!';
    } else if (hour < 18) {
      return 'Magandang hapon, ka-Milaor!';
    } else {
      return 'Magandang gabi, ka-Milaor!';
    }
  }

  /// Get random local tip
  String getRandomLocalTip() {
    final tips = [
      'Visit the Milaor Public Market every Tuesday, Friday, and Sunday for fresh local produce.',
      'The Feast of St. John the Baptist on June 24 is the town\'s biggest celebration.',
      'Milaor is known for its agricultural products, especially rice and coconut.',
      'The St. John the Baptist Parish Church is a historical landmark worth visiting.',
      'For emergency assistance, contact the Milaor Police Station at (054) 123-4567.',
      'Milaor has 10 barangays, each with its own barangay hall for local services.',
      'The municipal hall offers various services including business permits and civil registry.',
      'During rainy season, some low-lying areas may experience flooding. Stay updated with alerts.',
    ];

    return tips[DateTime.now().millisecondsSinceEpoch % tips.length];
  }

  /// Get barangay information
  Map<String, dynamic> getBarangayInfo(String barangayName) {
    final barangayData = {
      'San Antonio': {
        'population': 'Approx. 2,500',
        'barangayCaptain': 'Kap. Antonio Reyes',
        'landmark': 'San Antonio Elementary School',
      },
      'San Jose': {
        'population': 'Approx. 3,200',
        'barangayCaptain': 'Kap. Josefa Santos',
        'landmark': 'Milaor Health Center',
      },
      'San Roque': {
        'population': 'Approx. 2,800',
        'barangayCaptain': 'Kap. Roque Dela Cruz',
        'landmark': 'San Roque Chapel',
      },
      'Santa Cruz': {
        'population': 'Approx. 2,100',
        'barangayCaptain': 'Kap. Cruzita Mendoza',
        'landmark': 'Santa Cruz Elementary School',
      },
    };

    return barangayData[barangayName] ??
        {
          'population': 'Data not available',
          'barangayCaptain': 'Barangay Captain',
          'landmark': 'Barangay Hall',
        };
  }
}

/// Local context provider
final localContextProvider = Provider<MilaorLocalContext>((ref) {
  return MilaorLocalContext();
});

/// Current greeting provider
final currentGreetingProvider = Provider<String>((ref) {
  final context = ref.watch(localContextProvider);
  return context.getTimeBasedGreeting();
});

/// Local tip provider (refreshes every minute)
final localTipProvider = StreamProvider<String>((ref) {
  final context = ref.watch(localContextProvider);

  return Stream.periodic(const Duration(minutes: 1), (count) {
    return context.getRandomLocalTip();
  });
});

/// Barangays provider
final barangaysProvider = Provider<List<String>>((ref) {
  final context = ref.watch(localContextProvider);
  return context.barangays;
});

/// Landmarks provider
final landmarksProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final context = ref.watch(localContextProvider);
  return context.landmarks;
});

/// Festivals provider
final festivalsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final context = ref.watch(localContextProvider);
  return context.festivals;
});

/// Emergency contacts provider
final localEmergencyContactsProvider =
    Provider<List<Map<String, dynamic>>>((ref) {
  final context = ref.watch(localContextProvider);
  return context.emergencyContacts;
});
