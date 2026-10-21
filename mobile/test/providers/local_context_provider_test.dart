import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:may_laud/providers/local_context_provider.dart';

void main() {
  group('MilaorLocalContext Tests', () {
    late MilaorLocalContext localContext;

    setUp(() {
      localContext = MilaorLocalContext();
    });

    test('Should have correct municipality information', () {
      expect(localContext.municipalityName, 'Milaor');
      expect(localContext.province, 'Camarines Sur');
      expect(localContext.region, 'Bicol Region (Region V)');
      expect(localContext.country, 'Philippines');
    });

    test('Should have correct number of barangays', () {
      expect(localContext.barangays.length, 10);
      expect(localContext.barangays, contains('San Antonio'));
      expect(localContext.barangays, contains('San Jose'));
      expect(localContext.barangays, contains('Santo Niño'));
    });

    test('Should have landmarks with correct structure', () {
      expect(localContext.landmarks.length, greaterThan(0));

      final firstLandmark = localContext.landmarks.first;
      expect(firstLandmark['name'], isNotNull);
      expect(firstLandmark['type'], isNotNull);
      expect(firstLandmark['description'], isNotNull);
      expect(firstLandmark['location'], isNotNull);
      expect(firstLandmark['coordinates'], isNotNull);

      final coordinates = firstLandmark['coordinates'] as Map<String, dynamic>;
      expect(coordinates['lat'], isA<double>());
      expect(coordinates['lng'], isA<double>());
    });

    test('Should have festivals with correct structure', () {
      expect(localContext.festivals.length, greaterThan(0));

      final firstFestival = localContext.festivals.first;
      expect(firstFestival['name'], isNotNull);
      expect(firstFestival['month'], isNotNull);
      expect(firstFestival['description'], isNotNull);
    });

    test('Should have local officials', () {
      expect(localContext.localOfficials.length, greaterThan(0));
      expect(localContext.localOfficials['Municipal Mayor'], isNotNull);
      expect(localContext.localOfficials['Municipal Vice Mayor'], isNotNull);
    });

    test('Should have emergency contacts', () {
      expect(localContext.emergencyContacts.length, greaterThan(0));

      final firstContact = localContext.emergencyContacts.first;
      expect(firstContact['name'], isNotNull);
      expect(firstContact['number'], isNotNull);
      expect(firstContact['type'], isNotNull);
    });

    test('Should have economy information', () {
      expect(localContext.economy, isNotNull);
      expect(localContext.economy['primaryIndustries'], isA<List>());
      expect(localContext.economy['mainProducts'], isA<List>());
      expect(localContext.economy['marketDays'], isA<List>());
      expect(localContext.economy['businessHours'], isA<String>());
    });

    test('getTimeBasedGreeting should return appropriate greeting', () {
      // Note: getTimeBasedGreeting uses current time, so we can't test specific times
      // without mocking DateTime.now(). We'll just verify it returns a non-empty string.
      final greeting = localContext.getTimeBasedGreeting();
      expect(greeting, isNotEmpty);
      expect(greeting, contains('ka-Milaor'));
    });

    test('getRandomLocalTip should return a non-empty string', () {
      final tip = localContext.getRandomLocalTip();
      expect(tip, isNotEmpty);
      expect(tip.length, greaterThan(10));
    });

    test('getBarangayInfo should return correct information for valid barangay',
        () {
      final info = localContext.getBarangayInfo('San Jose');
      expect(info, isNotNull);
      expect(info['population'], 'Approx. 3,200');
      expect(info['barangayCaptain'], 'Kap. Josefa Santos');
      expect(info['landmark'], 'Milaor Health Center');
    });

    test('getBarangayInfo should return default data for invalid barangay', () {
      final info = localContext.getBarangayInfo('Non-existent Barangay');
      expect(info, isNotNull);
      expect(info['population'], 'Data not available');
      expect(info['barangayCaptain'], 'Barangay Captain');
      expect(info['landmark'], 'Barangay Hall');
    });
  });

  group('Local Context Providers Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('localContextProvider should provide MilaorLocalContext instance', () {
      final context = container.read(localContextProvider);
      expect(context, isA<MilaorLocalContext>());
      expect(context.municipalityName, 'Milaor');
    });

    test('currentGreetingProvider should provide time-based greeting', () {
      final greeting = container.read(currentGreetingProvider);
      expect(greeting, isNotEmpty);
      expect(greeting, contains('ka-Milaor'));
    });

    test('localTipProvider should provide stream of tips', () {
      final tipStream = container.read(localTipProvider);
      expect(tipStream, isA<AsyncValue<String>>());
    });

    test('barangaysProvider should provide list of barangays', () {
      final barangays = container.read(barangaysProvider);
      expect(barangays, isNotEmpty);
      expect(barangays.length, 10);
      expect(barangays, contains('San Antonio'));
    });

    test('landmarksProvider should provide list of landmarks', () {
      final landmarks = container.read(landmarksProvider);
      expect(landmarks, isNotEmpty);
      expect(landmarks.length, greaterThan(0));

      final firstLandmark = landmarks.first;
      expect(firstLandmark['name'], isNotNull);
      expect(firstLandmark['type'], isNotNull);
    });

    test('festivalsProvider should provide list of festivals', () {
      final festivals = container.read(festivalsProvider);
      expect(festivals, isNotEmpty);
      expect(festivals.length, greaterThan(0));

      final firstFestival = festivals.first;
      expect(firstFestival['name'], isNotNull);
      expect(firstFestival['month'], isNotNull);
    });

    test('localEmergencyContactsProvider should provide emergency contacts',
        () {
      final contacts = container.read(localEmergencyContactsProvider);
      expect(contacts, isNotEmpty);
      expect(contacts.length, greaterThan(0));

      final firstContact = contacts.first;
      expect(firstContact['name'], isNotNull);
      expect(firstContact['number'], isNotNull);
    });
  });
}
