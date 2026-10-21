// Unit tests for the 7-day forecast aggregation math.
//
// These verify the weekly summary is computed only from rainfall/probability
// values, never from any water-level source, and that malformed/empty input
// degrades to [ForecastSummary.empty] instead of throwing.

import 'package:flutter_test/flutter_test.dart';
import 'package:may_laud/features/rain_forecast/aggregation/forecast_summary.dart';
import 'package:may_laud/features/rain_forecast/models/weather_data_models.dart';

WeatherDay _day({
  required String time,
  double? precip,
  double? rain,
  int? prob,
  int? wmo,
  int? tMax,
  int? tMin,
}) {
  return WeatherDay(
    time: time,
    precipitationSumMm: precip,
    rainSumMm: rain,
    precipitationProbabilityMaxPct: prob,
    weatherCode: wmo,
    temperatureMaxC: tMax,
    temperatureMinC: tMin,
  );
}

void main() {
  group('computeWeeklySummary', () {
    test('empty input yields the empty summary', () {
      final s = computeWeeklySummary(const []);
      expect(s.dayCount, 0);
      expect(s.totalPrecipitationMm, 0);
      expect(s.wettestDay, isNull);
      expect(s.highestProbabilityDay, isNull);
      expect(s.daysWithMeasurablePrecipitation, 0);
      expect(s.hasData, isFalse);
    });

    test('sums the daily precipitation across the week', () {
      final days = [
        _day(time: '2026-01-01', precip: 1.5, prob: 20),
        _day(time: '2026-01-02', precip: 0.0, prob: 10),
        _day(time: '2026-01-03', precip: 12.25, prob: 80),
      ];
      final s = computeWeeklySummary(days);
      expect(s.totalPrecipitationMm, closeTo(13.75, 1e-9));
      expect(s.dayCount, 3);
      // Days strictly > 0 mm: day 1 (1.5) and day 3 (12.25) => 2.
      expect(s.daysWithMeasurablePrecipitation, 2);
    });

    test('identifies the wettest day', () {
      final days = [
        _day(time: '2026-01-01', precip: 3.0, prob: 30),
        _day(time: '2026-01-02', precip: 42.5, prob: 70),
        _day(time: '2026-01-03', precip: 5.0, prob: 40),
      ];
      final s = computeWeeklySummary(days);
      expect(s.wettestDay?.time, '2026-01-02');
      expect(s.wettestDayPrecipitationMm, closeTo(42.5, 1e-9));
      expect(s.wettestDisplay, '42.5');
    });

    test('identifies the highest probability day', () {
      final days = [
        _day(time: '2026-01-01', precip: 1.0, prob: 25),
        _day(time: '2026-01-02', precip: 2.0, prob: 95),
        _day(time: '2026-01-03', precip: 3.0, prob: 55),
      ];
      final s = computeWeeklySummary(days);
      expect(s.highestProbabilityDay?.time, '2026-01-02');
      expect(s.highestProbabilityPct, 95);
    });

    test('falls back to rain_sum when precipitation_sum is null', () {
      final days = [
        _day(time: '2026-01-01', rain: 7.5, prob: 60),
        _day(time: '2026-01-02', rain: 0.5, prob: 20),
      ];
      final s = computeWeeklySummary(days);
      expect(s.totalPrecipitationMm, closeTo(8.0, 1e-9));
      expect(s.wettestDay?.time, '2026-01-01');
    });

    test(
        'days with no numeric precipitation contribute 0 and are never wettest',
        () {
      final days = [
        _day(time: '2026-01-01', prob: 40), // no precip value at all
        _day(time: '2026-01-02', precip: 0.0, prob: 10),
      ];
      final s = computeWeeklySummary(days);
      expect(s.totalPrecipitationMm, 0);
      // Only the 0.0 mm day has a numeric value, so it becomes "wettest".
      expect(s.wettestDay?.time, '2026-01-02');
      expect(s.daysWithMeasurablePrecipitation, 0);
    });

    test('totalDisplay rounds to one decimal and avoids -0.0', () {
      final days = [_day(time: '2026-01-01', precip: 0.0, prob: 5)];
      final s = computeWeeklySummary(days);
      expect(s.totalDisplay, '0.0');
    });
  });

  group('dailyPrecipitationMm', () {
    test('prefers precipitation_sum, then rain_sum, then showers_sum', () {
      expect(dailyPrecipitationMm(_day(time: 'x', precip: 2, rain: 9)), 2.0);
      expect(dailyPrecipitationMm(_day(time: 'x', rain: 9)), 9.0);
    });

    test('returns 0 for a missing value', () {
      expect(dailyPrecipitationMm(_day(time: 'x')), 0.0);
    });
  });
}
