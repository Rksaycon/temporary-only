import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:may_laud/providers/content_providers.dart';

void main() {
  group('Announcement Model Tests', () {
    test('Announcement.fromJson should parse valid JSON', () {
      // Arrange — keys match a `announcements` row from Supabase (see
      // Announcement.fromJson in content_providers.dart).
      final json = {
        'id': 'announcement-123',
        'title': 'Town Hall Meeting',
        'description': 'Monthly town hall meeting for all residents',
        'category': 'Government',
        'created_at': '2024-03-15T14:30:00.000Z',
        'image_url': 'https://example.com/image.jpg',
        'is_important': true,
        'is_read': false,
      };

      // Act
      final announcement = Announcement.fromJson(json);

      // Assert
      expect(announcement.id, 'announcement-123');
      expect(announcement.title, 'Town Hall Meeting');
      expect(announcement.description,
          'Monthly town hall meeting for all residents');
      expect(announcement.category, 'Government');
      // fromJson() converts the UTC created_at to local time before
      // storing it, so compare via isAtSameMomentAs rather than ==.
      expect(announcement.date
          .isAtSameMomentAs(DateTime.parse(json['created_at'] as String)), true);
      expect(announcement.imageUrl, 'https://example.com/image.jpg');
      expect(announcement.isImportant, true);
      expect(announcement.isRead, false);
    });

    test('formattedDate should return correct format', () {
      // Arrange
      final announcement = Announcement(
        id: 'test',
        title: 'Test',
        description: 'Test',
        category: 'Test',
        date: DateTime.utc(2024, 3, 15, 14, 30),
      );

      // Act
      final formatted = announcement.formattedDate;

      // Assert
      expect(formatted, contains('Mar 15, 2024'));
    });

    test('copyWith should update isRead while preserving other fields', () {
      // Arrange
      final original = Announcement(
        id: 'original',
        title: 'Original Title',
        description: 'Original Description',
        category: 'General',
        date: DateTime.utc(2024, 1, 1),
        isImportant: false,
        isRead: false,
      );

      // Act — Announcement.copyWith only supports overriding `isRead`
      // (see content_providers.dart); every other field always carries
      // over unchanged.
      final updated = original.copyWith(isRead: true);

      // Assert
      expect(updated.id, 'original');
      expect(updated.title, 'Original Title');
      expect(updated.description, 'Original Description');
      expect(updated.category, 'General');
      expect(updated.date, DateTime.utc(2024, 1, 1));
      expect(updated.isImportant, false);
      expect(updated.isRead, true);
    });
  });

  group('AppNotification Model Tests', () {
    test('AppNotification.fromJson should parse valid JSON', () {
      // Arrange — keys match a `notifications` row from Supabase (see
      // AppNotification.fromJson in content_providers.dart).
      final json = {
        'id': 'notification-123',
        'title': 'New Announcement',
        'message': 'A new town hall meeting has been scheduled',
        'created_at': '2024-03-15T10:00:00.000Z',
        'type': 'announcement',
        'is_read': false,
        'data': {'announcementId': 'announcement-123'},
      };

      // Act
      final notification = AppNotification.fromJson(json);

      // Assert
      expect(notification.id, 'notification-123');
      expect(notification.title, 'New Announcement');
      expect(
          notification.message, 'A new town hall meeting has been scheduled');
      expect(notification.timestamp, DateTime.utc(2024, 3, 15, 10, 0));
      expect(notification.type, 'announcement');
      expect(notification.isRead, false);
      expect(notification.data?['announcementId'], 'announcement-123');
    });

    test('copyWith should update isRead while preserving other fields', () {
      // Arrange
      final original = AppNotification(
        id: 'test',
        title: 'Test',
        message: 'Test',
        timestamp: DateTime.utc(2024, 3, 15, 10, 0),
        type: 'announcement',
        isRead: false,
      );

      // Act
      final updated = original.copyWith(isRead: true);

      // Assert
      expect(updated.id, 'test');
      expect(updated.title, 'Test');
      expect(updated.isRead, true);
    });
  });

  group('Content Providers Tests', () {
    // NOTE — announcementsProvider/notificationsProvider now fetch their
    // initial data from Supabase on construction (see
    // AnnouncementsProvider/NotificationsProvider in
    // content_providers.dart), which this test process never connects
    // to (Supabase.initialize() is never called here), so they start —
    // and, absent a live backend, stay — empty rather than preloaded
    // with fixture data. Each test below seeds what it needs directly
    // through the notifier's local mutators (addAnnouncement /
    // addNotification) instead of assuming data is already there.
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('addAnnouncement should increase announcements count', () {
      final notifier = container.read(announcementsProvider.notifier);
      final initialCount = container.read(announcementsProvider).length;

      notifier.addAnnouncement(Announcement(
        id: 'test-new-announcement',
        title: 'Test Announcement',
        description: 'Test Description',
        category: 'Test',
        date: DateTime.now(),
      ));

      final updatedCount = container.read(announcementsProvider).length;
      expect(updatedCount, initialCount + 1);
    });

    test('addNotification should increase notifications count', () {
      final notifier = container.read(notificationsProvider.notifier);
      final initialCount = container.read(notificationsProvider).length;

      notifier.addNotification(AppNotification(
        id: 'test-new-notification',
        title: 'Test Notification',
        message: 'Test Message',
        timestamp: DateTime.now(),
        type: 'test',
      ));

      final updatedCount = container.read(notificationsProvider).length;
      expect(updatedCount, initialCount + 1);
    });

    test('unreadNotificationsCountProvider should count unread notifications',
        () {
      final notifier = container.read(notificationsProvider.notifier);
      notifier.addNotification(AppNotification(
        id: 'n1',
        title: 'Read one',
        message: '-',
        timestamp: DateTime.now(),
        type: 'system',
        isRead: true,
      ));
      notifier.addNotification(AppNotification(
        id: 'n2',
        title: 'Unread one',
        message: '-',
        timestamp: DateTime.now(),
        type: 'system',
        isRead: false,
      ));

      final count = container.read(unreadNotificationsCountProvider);
      expect(count, 1);
    });

    test(
        'importantAnnouncementsProvider should filter important announcements',
        () {
      final notifier = container.read(announcementsProvider.notifier);
      notifier.addAnnouncement(Announcement(
        id: 'a1',
        title: 'Important',
        description: '-',
        category: 'Test',
        date: DateTime.now(),
        isImportant: true,
      ));
      notifier.addAnnouncement(Announcement(
        id: 'a2',
        title: 'Regular',
        description: '-',
        category: 'Test',
        date: DateTime.now(),
        isImportant: false,
      ));

      final importantAnnouncements =
          container.read(importantAnnouncementsProvider);

      expect(importantAnnouncements.length, 1);
      expect(importantAnnouncements.first.id, 'a1');
    });
  });

  group('DocumentRequest Model Tests', () {
    test('fromJson should parse a document_requests row', () {
      // Arrange — keys match a `document_requests` row from Supabase (see
      // DocumentRequest.fromJson in content_providers.dart).
      final json = {
        'id': 'a1b2c3d4-1111-2222-3333-444455556666',
        'document_type': 'Barangay Clearance',
        'purpose': 'Employment requirement',
        'status': 'processing',
        'fee': '\u20b150.00',
        'notes': 'Urgency: Normal (3-5 days)',
        'created_at': '2024-03-15T14:30:00.000Z',
        'updated_at': '2024-03-16T09:00:00.000Z',
      };

      // Act
      final request = DocumentRequest.fromJson(json);

      // Assert
      expect(request.id, 'a1b2c3d4-1111-2222-3333-444455556666');
      expect(request.documentType, 'Barangay Clearance');
      expect(request.purpose, 'Employment requirement');
      expect(request.status, 'processing');
      expect(request.fee, '\u20b150.00');
      expect(request.notes, 'Urgency: Normal (3-5 days)');
      expect(request.normalizedStatus, 'processing');
      expect(request.updatedAt, isNotNull);
    });

    test('fromJson should parse the fields the request form collects', () {
      // These are the columns added by
      // supabase/document_requests_full_details.sql so the web admin can show
      // everything the resident typed on the Document Request screen.
      final json = {
        'id': 'a1b2c3d4-1111-2222-3333-444455556666',
        'document_type': 'Barangay Clearance',
        'purpose': 'Employment requirement',
        'status': 'ready',
        'fee': '\u20b150.00',
        'notes': 'Urgency: Normal (3-5 days)',
        'full_name': 'Juan Dela Cruz',
        'address': '123 Poblacion, Milaor',
        'urgency': 'Normal (3-5 days)',
        'additional_notes': 'Please call before pickup',
        'attachment_urls': ['https://example.com/id.jpg'],
        'created_at': '2024-03-15T14:30:00.000Z',
        'updated_at': '2024-03-16T09:00:00.000Z',
      };

      final request = DocumentRequest.fromJson(json);

      expect(request.fullName, 'Juan Dela Cruz');
      expect(request.requesterName, 'Juan Dela Cruz');
      expect(request.address, '123 Poblacion, Milaor');
      expect(request.urgency, 'Normal (3-5 days)');
      expect(request.additionalNotes, 'Please call before pickup');
      expect(request.attachmentUrls, ['https://example.com/id.jpg']);
      expect(request.hasAttachments, isTrue);
    });

    test('requesterName falls back when full_name is absent or blank', () {
      DocumentRequest req({String? fullName}) => DocumentRequest(
            id: 'id-1',
            documentType: 'Barangay Clearance',
            purpose: '-',
            status: 'pending',
            fullName: fullName,
            createdAt: DateTime.utc(2024, 1, 1),
          );

      // Rows created before the full_name column existed (and the offline
      // fallback row) must still render a sensible tracking title.
      expect(req().requesterName, 'You');
      expect(req(fullName: '   ').requesterName, 'You');
      expect(req(fullName: ' Maria Santos ').requesterName, 'Maria Santos');

      // No attachments on an old row -> the detail screen hides that section.
      expect(req().hasAttachments, isFalse);
      expect(req().attachmentUrls, isEmpty);
    });

    test('status getters map every status to a label and timeline step', () {
      DocumentRequest req(String status) => DocumentRequest(
            id: 'id-$status',
            documentType: 'Document',
            purpose: '-',
            status: status,
            createdAt: DateTime.utc(2024, 1, 1),
          );

      expect(req('pending').statusLabel, 'Pending Review');
      expect(req('PROCESSING').statusLabel, 'Processing');
      expect(req('ready').statusLabel, 'Ready for Pickup');
      expect(req('released').statusLabel, 'Released');
      expect(req('completed').statusLabel, 'Completed');
      expect(req('rejected').statusLabel, 'Rejected');

      expect(req('pending').timelineStep, 0);
      expect(req('processing').timelineStep, 1);
      expect(req('ready').timelineStep, 2);
      expect(req('released').timelineStep, 3);
      expect(req('completed').timelineStep, 3);

      expect(req('rejected').isRejected, true);
      expect(req('rejected').statusMessage, contains('rejected'));
      expect(req('ready').statusMessage, contains('ready'));
    });

    test('reference is derived from the row id and never empty', () {
      final uuid = DocumentRequest(
        id: 'a1b2c3d4-1111-2222-3333-444455556666',
        documentType: 'Document',
        purpose: '-',
        status: 'pending',
        createdAt: DateTime.utc(2024, 1, 1),
      );
      expect(uuid.reference, 'MLR-A1B2C3D4');

      // Offline-fallback ids are epoch-millis strings; still a valid ref.
      final short = DocumentRequest(
        id: '1700000000000',
        documentType: 'Document',
        purpose: '-',
        status: 'pending',
        createdAt: DateTime.utc(2024, 1, 1),
      );
      expect(short.reference, startsWith('MLR-'));
    });
  });

  group('Document requests provider tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('addRequest feeds the live tracking list and stats', () {
      final notifier = container.read(documentRequestsProvider.notifier);

      notifier.addRequest(DocumentRequest(
        id: 'r1',
        documentType: 'Barangay Clearance',
        purpose: '-',
        status: 'pending',
        createdAt: DateTime.now(),
      ));
      notifier.addRequest(DocumentRequest(
        id: 'r2',
        documentType: 'Business Permit',
        purpose: '-',
        status: 'ready',
        createdAt: DateTime.now(),
      ));

      expect(container.read(documentRequestsProvider).length, 2);

      final stats = container.read(documentRequestStatsProvider);
      expect(stats['total'], 2);
      expect(stats['pending'], 1);
      expect(stats['approved'], 1);
    });
  });

  group('CitizenReport Model Tests', () {
    test('fromJson should parse a citizen_reports row', () {
      // Arrange — keys match a `citizen_reports` row (see schema.sql and
      // CitizenReportService.submitReport() in app_services.dart).
      final json = {
        'id': 'a1b2c3d4-1111-2222-3333-444455556666',
        'user_id': 'user-123',
        'category': 'Fire',
        'subcategory': 'Burning trash bin',
        'description': 'Trash bin on fire near the plaza',
        'location': 'Milaor Plaza',
        'photo_urls': ['https://example.com/a.jpg'],
        'contact': '09171234567',
        'severity': 'High',
        'status': 'in_progress',
        'requires_manual_review': false,
        'created_at': '2024-03-15T14:30:00.000Z',
        'updated_at': '2024-03-16T08:00:00.000Z',
      };

      // Act
      final report = CitizenReport.fromJson(json);

      // Assert
      expect(report.id, 'a1b2c3d4-1111-2222-3333-444455556666');
      expect(report.category, 'Fire');
      expect(report.subcategory, 'Burning trash bin');
      expect(report.displayTitle, 'Burning trash bin');
      expect(report.description, 'Trash bin on fire near the plaza');
      expect(report.location, 'Milaor Plaza');
      expect(report.photoUrls, ['https://example.com/a.jpg']);
      expect(report.contact, '09171234567');
      expect(report.severity, 'High');
      expect(report.status, 'in_progress');
      expect(report.requiresManualReview, false);
      expect(report.isOngoing, true);
      expect(report.isResolved, false);
      expect(report.submittedLabel, isNotEmpty);
      expect(report.lastUpdatedLabel, isNotEmpty);
    });

    test('status getters map every status to a label, message and step', () {
      CitizenReport req(String status) => CitizenReport(
            id: 'id-$status',
            category: 'Flood',
            status: status,
            createdAt: DateTime.utc(2024, 1, 1),
            updatedAt: DateTime.utc(2024, 1, 1),
          );

      expect(req('received').statusLabel, 'Received');
      expect(req('assigned').statusLabel, 'Assigned');
      expect(req('IN_PROGRESS').statusLabel, 'Ongoing');
      expect(req('resolved').statusLabel, 'Resolved');
      expect(req('closed').statusLabel, 'Closed');

      expect(req('received').timelineStep, 0);
      expect(req('assigned').timelineStep, 1);
      expect(req('in_progress').timelineStep, 2);
      expect(req('resolved').timelineStep, 3);
      expect(req('closed').timelineStep, 3);

      expect(req('in_progress').isOngoing, true);
      expect(req('resolved').isResolved, true);
      expect(req('closed').isResolved, true);
      expect(req('resolved').statusMessage, contains('resolved'));
      expect(req('in_progress').statusMessage, contains('Ongoing'));

      // Unknown/legacy values still produce a usable label and step.
      expect(req('weird_value').statusLabel, 'Weird_value');
      expect(req('').normalizedStatus, 'received');
      expect(req('').statusLabel, 'Received');
      expect(req('').timelineStep, 0);
    });

    test('verification and feedback remain separate from report progress', () {
      CitizenReport report(String decision) => CitizenReport.fromJson({
        'id': 'review-test', 'category': 'Fire', 'status': 'received',
        'verification_status': decision, 'verification_note': 'Please provide a location.',
      });
      expect(report('pending').verificationLabel, 'Pending verification');
      expect(report('pending').statusLabel, 'Received');
      expect(report('pending').verificationMessage, contains('verification'));
      expect(report('rejected').isOngoing, false);
      expect(report('rejected').isResolved, false);
      expect(report('rejected').verificationLabel, 'Rejected');
      expect(report('needs_information').verificationNote, contains('location'));
      expect(report('needs_information').verificationLabel, 'More information needed');
      expect(CitizenReport.fromJson({'status': 'assigned'}).verificationStatus, 'verified');
      expect(CitizenReport.fromJson({}).verificationStatus, 'pending');
    });

    test('reference is derived from the row id and matches the SQL trigger', () {
      // RPT- + first 8 chars of the uuid without dashes — the exact formula
      // citizen_reports_status_tracking.sql uses for push text.
      final uuid = CitizenReport(
        id: 'a1b2c3d4-1111-2222-3333-444455556666',
        category: 'Fire',
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1),
      );
      expect(uuid.reference, 'RPT-A1B2C3D4');

      // Malformed/short ids still yield a valid, non-throwing reference.
      final short = CitizenReport(
        id: 'abc',
        category: 'Fire',
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1),
      );
      expect(short.reference, 'RPT-ABC');

      final empty = CitizenReport(
        id: '',
        category: 'Fire',
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1),
      );
      expect(empty.reference, 'RPT-');
    });

    test('displayTitle falls back to the category for legacy rows', () {
      final legacy = CitizenReport(
        id: 'x',
        category: 'Road Damage',
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1),
      );
      expect(legacy.displayTitle, 'Road Damage');

      final titled = CitizenReport(
        id: 'x',
        category: 'Road Damage',
        subcategory: '  Pothole on Burgos St.  ',
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1),
      );
      expect(titled.displayTitle, 'Pothole on Burgos St.');
    });
  });

  group('Citizen reports provider tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    CitizenReport report(String id, String status) => CitizenReport(
          id: id,
          category: 'Flood',
          status: status,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    test('addReport feeds the live history list and stats', () {
      final notifier = container.read(citizenReportsProvider.notifier);

      notifier.addReport(report('r1', 'received'));
      notifier.addReport(report('r2', 'in_progress'));
      notifier.addReport(report('r3', 'resolved'));
      // Duplicate ids are ignored — a realtime INSERT arriving after a local
      // add must not double-list the same report.
      notifier.addReport(report('r1', 'received'));

      expect(container.read(citizenReportsProvider).length, 3);

      final stats = container.read(citizenReportStatsProvider);
      expect(stats['total'], 3);
      expect(stats['ongoing'], 2); // received + in_progress
      expect(stats['resolved'], 1);
    });

    test('newest addReport lands first in the history', () {
      final notifier = container.read(citizenReportsProvider.notifier);
      notifier.addReport(report('old', 'resolved'));
      notifier.addReport(report('new', 'received'));

      final ids = [
        for (final r in container.read(citizenReportsProvider)) r.id,
      ];
      expect(ids, ['new', 'old']);
    });
  });
}

