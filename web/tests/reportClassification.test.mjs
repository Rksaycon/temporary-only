import assert from 'node:assert/strict';
import {
  AI_ASSESSMENT_OUTCOMES,
  aiCategoryOf,
  aiAssessmentOutcome,
  classificationSource,
  effectiveCategoryOf,
  isAiCategoryAccepted,
  isAiCorroborated,
} from '../src/reportClassification.js';

const report = (category, detected, extra = {}) => ({
  category,
  ai_detected_image_category: detected,
  ai_image_valid: true,
  requires_manual_review: false,
  verification_status: 'pending',
  ...extra,
});

assert.equal(aiAssessmentOutcome(report('Fire', 'Fire')), AI_ASSESSMENT_OUTCOMES.CORROBORATED);
assert.equal(aiAssessmentOutcome(report('Flooding', 'Fire')), AI_ASSESSMENT_OUTCOMES.MISMATCH);
assert.equal(aiAssessmentOutcome(report('Medical Emergency', 'Medical Emergency')), AI_ASSESSMENT_OUTCOMES.LEARNING_MODE);
const medicalNeedsReview = report('Medical Emergency', 'Medical Emergency', {
  requires_manual_review: true,
});
assert.equal(aiCategoryOf(medicalNeedsReview), 'Medical Emergency');
assert.equal(aiAssessmentOutcome(medicalNeedsReview), AI_ASSESSMENT_OUTCOMES.MANUAL_REVIEW);
assert.equal(isAiCategoryAccepted(medicalNeedsReview), false);
assert.equal(effectiveCategoryOf(medicalNeedsReview), 'Medical Emergency');
assert.equal(classificationSource(medicalNeedsReview), 'Citizen reported');
assert.equal(aiAssessmentOutcome(report('Infrastructure Damage', 'Fire')), AI_ASSESSMENT_OUTCOMES.LEARNING_MODE);
assert.equal(aiAssessmentOutcome(report('Traffic', 'Fire')), AI_ASSESSMENT_OUTCOMES.NOT_APPLICABLE);
assert.equal(aiAssessmentOutcome(report('Fire', 'Fire', { ai_image_valid: false })), AI_ASSESSMENT_OUTCOMES.MANUAL_REVIEW);
assert.equal(aiCategoryOf(report('Medical Emergency', 'Medical Emergency', { ai_image_valid: false, requires_manual_review: true })), '');
assert.equal(isAiCorroborated(report('Medical Emergency', 'Medical Emergency')), false);

const mismatch = report('Fire', 'Medical Emergency');
assert.equal(effectiveCategoryOf(mismatch), 'Fire');
assert.equal(classificationSource(mismatch), 'Citizen reported');

const verified = report('Fire', 'Medical Emergency', {
  verification_status: 'verified',
  verified_category: 'Infrastructure Damage',
});
assert.equal(effectiveCategoryOf(verified), 'Infrastructure Damage');
assert.equal(classificationSource(verified), 'Admin verified');

console.log('AI routing safety policy checks passed.');
