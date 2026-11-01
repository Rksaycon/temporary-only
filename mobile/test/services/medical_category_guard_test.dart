import 'package:flutter_test/flutter_test.dart';
import 'package:may_laud/services/ai_triage_service.dart';
import 'package:may_laud/services/app_services.dart';

ImageVerificationResult medicalResult(
  double confidence, {
  bool autoSelectAllowed = true,
  String? reviewReason,
}) {
  return ImageVerificationResult(
    isValidPhoto: true,
    detectedCategory: 'Medical Emergency',
    requiresManualReview: false,
    autoSelectAllowed: autoSelectAllowed,
    validityModelConfidence: 0,
    categoryConfidence: confidence,
    dominantFaceDetected: false,
    reviewReason: reviewReason,
  );
}

void main() {
  group('AccidentTriageDecision', () {
    test('maps structured safety answers to conservative priorities', () {
      expect(
        AccidentTriageDecision.injuryOrImmediateDanger.suggestedSeverity,
        'High',
      );
      expect(AccidentTriageDecision.notSure.suggestedSeverity, 'Medium');
      expect(
        AccidentTriageDecision.noInjuryRoadBlocked.suggestedSeverity,
        'Medium',
      );
      expect(
        AccidentTriageDecision.noInjuryRoadClear.suggestedSeverity,
        'Low',
      );
    });

    test('stores the reason without a model confidence claim', () {
      final note = AccidentTriageDecision.notSure.reportNote;
      expect(note, contains('not sure'));
      expect(note, contains('Suggested priority: Medium'));
      expect(note, isNot(contains('%')));
    });
  });

  group('FireTriageDecision', () {
    test('maps secondary fire evidence to conservative priorities', () {
      expect(
        FireTriageDecision.peopleOrStructuresInDanger.suggestedSeverity,
        'High',
      );
      expect(FireTriageDecision.notSure.suggestedSeverity, 'Medium');
      expect(
        FireTriageDecision.activeUncontrolledFire.suggestedSeverity,
        'Medium',
      );
      expect(
        FireTriageDecision.controlledOrNoActiveDanger.suggestedSeverity,
        'Low',
      );
    });
  });

  group('MedicalCategoryGuard', () {
    test('one photo at the 65% safety gate can request confirmation', () {
      expect(
        MedicalCategoryGuard.qualifies(
          [medicalResult(65)],
          attachedPhotoCount: 1,
        ),
        isTrue,
      );
      expect(
        MedicalCategoryGuard.qualifies(
          [medicalResult(64.99)],
          attachedPhotoCount: 1,
        ),
        isFalse,
      );
    });

    test('multiple photos require two candidates or one strong result', () {
      expect(
        MedicalCategoryGuard.qualifies(
          [medicalResult(65), medicalResult(66)],
          attachedPhotoCount: 2,
        ),
        isTrue,
      );
      expect(
        MedicalCategoryGuard.qualifies(
          [medicalResult(89), medicalResult(64)],
          attachedPhotoCount: 2,
        ),
        isFalse,
      );
      expect(
        MedicalCategoryGuard.qualifies(
          [medicalResult(90), medicalResult(64)],
          attachedPhotoCount: 2,
        ),
        isTrue,
      );
    });

    test('strong road-crash conflicts can request citizen confirmation', () {
      expect(
        MedicalCategoryGuard.qualifies(
          [
            medicalResult(
              99,
              autoSelectAllowed: false,
              reviewReason: 'multiple_categories_detected',
            ),
          ],
          attachedPhotoCount: 1,
        ),
        isTrue,
      );
    });
  });

  test('confirmed medical suggestions still require admin review', () {
    final service = CitizenReportService();
    final assessment = service.assessmentFromSuggestion(
      suggestion: ReportCategorySuggestion(
        checkedPhotoCount: 1,
        suggestedCategory: 'Medical Emergency',
        suggestedConfidence: 99,
        supportingPhotoCount: 1,
        hasConflictingResults: false,
        aiUnavailable: false,
        results: [medicalResult(99)],
      ),
      category: 'Medical Emergency',
    );

    expect(assessment.hasTrustedMatch, isTrue);
    expect(assessment.requiresManualReview, isTrue);
  });
}
