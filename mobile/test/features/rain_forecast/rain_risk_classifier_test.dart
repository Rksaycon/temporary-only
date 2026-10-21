// Unit tests for the transparent rain-risk classifier.
//
// Verifies that labels follow the documented probability thresholds and that
// measured-water classification uses the station's own threshold and never
// mixes in rainfall.

import 'package:flutter_test/flutter_test.dart';
import 'package:may_laud/features/rain_forecast/models/weather_data_models.dart';
import 'package:may_laud/features/rain_forecast/models/weather_risk_models.dart';
import 'package:may_laud/features/rain_forecast/risk/rain_risk_classifier.dart';
import 'package:may_laud/features/rain_forecast/types.dart';

const _loc = Location(
  id: 'mld_milaor',
  name: 'Milaor',
  province: 'Camarines Sur',
  latitude: 13.7306,
  longitude: 123.4270,
);

WeatherDay _day(int prob) => WeatherDay(
      time: '2026-01-0${prob % 9 + 1}',
      precipitationProbabilityMaxPct: prob,
      precipitationSumMm: 1.0,
    );

void main() {
  group('classifyRainOutlook', () {
    test('empty daily list is Unavailable', () {
      final rule = RainRiskClassifier.classifyRainOutlook(
          daily: const [], location: _loc);
      expect(rule.label, 'Unavailable');
      expect(rule.isRainfallOnly, isTrue);
    });

    test('no rain and no probability is "No measurable rain expected"', () {
      final rule = RainRiskClassifier.classifyRainOutlook(
        daily: const [WeatherDay(time: '2026-01-01')],
        location: _loc,
      );
      expect(rule.label, 'No measurable rain expected');
    });

    test('max probability >= 80 is High rain expected', () {
      final rule = RainRiskClassifier.classifyRainOutlook(
        daily: [_day(10), _day(85), _day(50)],
        location: _loc,
      );
      expect(rule.label, 'High rain expected');
    });

    test('max probability >= 60 (but < 80) is Moderate', () {
      final rule = RainRiskClassifier.classifyRainOutlook(
        daily: [_day(20), _day(65)],
        location: _loc,
      );
      expect(rule.label, 'Moderate rain expected');
    });

    test('max probability >= 30 (but < 60) is Low rain possible', () {
      final rule = RainRiskClassifier.classifyRainOutlook(
        daily: [_day(10), _day(35)],
        location: _loc,
      );
      expect(rule.label, 'Low rain possible');
    });

    test('all labels are rainfall-only (never a river height)', () {
      final rule = RainRiskClassifier.classifyRainOutlook(
        daily: [_day(90)],
        location: _loc,
      );
      expect(rule.isRainfallOnly, isTrue);
      expect(rule.category, 'rain');
    });
  });

  group('classifyMeasuredWater', () {
    WaterLevelReading reading(String threshold) => WaterLevelReading(
          station: 'Test Station',
          riverName: 'Test River',
          locationName: 'Milaor',
          latitude: 13.7,
          longitude: 123.4,
          levelMeters: 2.0,
          measurementTimestamp: '2026-01-01T00:00',
          officialWarningThresholdMeters: threshold,
          raw: const {},
        );

    test('at/above threshold is Elevated', () {
      final rule = RainRiskClassifier.classifyMeasuredWater(
        levelMeters: 3.0,
        reading: reading('2.5'),
      );
      expect(rule.label, 'Elevated');
      expect(rule.isRainfallOnly, isFalse);
    });

    test('below threshold is Normal', () {
      final rule = RainRiskClassifier.classifyMeasuredWater(
        levelMeters: 1.0,
        reading: reading('2.5'),
      );
      expect(rule.label, 'Normal');
    });

    test('no threshold => Normal (no arbitrary universal cutoff)', () {
      final r = WaterLevelReading(
        station: 'S',
        riverName: 'R',
        locationName: 'Milaor',
        latitude: 13.7,
        longitude: 123.4,
        levelMeters: 99.0, // very high, but no published threshold
        officialWarningThresholdMeters: null,
        raw: const {},
      );
      final rule = RainRiskClassifier.classifyMeasuredWater(
          levelMeters: 99.0, reading: r);
      expect(rule.label, 'Normal');
    });
  });
}
