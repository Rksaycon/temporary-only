/// Pure, side-effect-free aggregation of a 7-day rainfall outlook.
///
/// Everything here is computed only from the Open-Meteo `daily` values
/// (`precipitation_sum` / `rain_sum` / `showers_sum` and
/// `precipitation_probability_max`). These are FORECAST summaries, not
/// guaranteed rainfall totals and never river heights — see
/// `models/weather_risk_models.dart` for the source-separation contract.
library;

import 'package:flutter/foundation.dart';

import '../models/weather_data_models.dart';

/// The effective daily precipitation in mm for a single day.
///
/// Open-Meteo can return `precipitation_sum`, `rain_sum`, or `showers_sum`
/// depending on the location/time; we prefer the most complete value and fall
/// back gracefully. A day with no numeric value at all contributes 0 mm to the
/// weekly total but is never reported as a "wettest day".
double dailyPrecipitationMm(WeatherDay day) {
  final v = day.precipitationSumMm ?? day.rainSumMm ?? day.showersSumMm;
  return (v == null || v.isNaN) ? 0.0 : v.clamp(0.0, double.infinity);
}

/// Whether a day has any numeric precipitation value at all (even 0.0 mm).
bool _hasNumericPrecipitation(WeatherDay day) =>
    (day.precipitationSumMm ?? day.rainSumMm ?? day.showersSumMm) != null;

/// Immutable weekly forecast summary derived from the daily outlook.
@immutable
class ForecastSummary {
  /// Sum of the daily precipitation values across the period (mm).
  final double totalPrecipitationMm;

  /// Day with the highest forecast precipitation (null when no day has a
  /// numeric precipitation value).
  final WeatherDay? wettestDay;

  /// The precipitation (mm) of [wettestDay]; 0 when unknown.
  final double wettestDayPrecipitationMm;

  /// Day with the highest forecast precipitation probability (null when no day
  /// reports a probability).
  final WeatherDay? highestProbabilityDay;

  /// The probability (%) of [highestProbabilityDay]; null when unknown.
  final int? highestProbabilityPct;

  /// Number of days with a strictly positive (> 0 mm) forecast precipitation.
  final int daysWithMeasurablePrecipitation;

  /// Number of days included in the summary.
  final int dayCount;

  const ForecastSummary({
    required this.totalPrecipitationMm,
    this.wettestDay,
    required this.wettestDayPrecipitationMm,
    this.highestProbabilityDay,
    this.highestProbabilityPct,
    required this.daysWithMeasurablePrecipitation,
    required this.dayCount,
  });

  /// An empty summary for the "no data" case (e.g. empty or failed forecast).
  static const ForecastSummary empty = ForecastSummary(
    totalPrecipitationMm: 0,
    wettestDayPrecipitationMm: 0,
    daysWithMeasurablePrecipitation: 0,
    dayCount: 0,
  );

  /// True when at least one day has a usable precipitation value.
  bool get hasData => dayCount > 0 && wettestDay != null;

  /// Total rounded to one decimal place for display.
  String get totalDisplay => _oneDecimal(totalPrecipitationMm);

  /// Wettest-day amount rounded to one decimal place for display.
  String get wettestDisplay => _oneDecimal(wettestDayPrecipitationMm);

  static String _oneDecimal(double v) {
    // Avoid "-0.0" and keep a stable one-decimal representation.
    if (v.abs() < 0.05) return '0.0';
    return v.toStringAsFixed(1);
  }
}

/// Computes a [ForecastSummary] from the raw daily outlook.
///
/// Never throws: malformed/empty input yields [ForecastSummary.empty].
ForecastSummary computeWeeklySummary(List<WeatherDay> daily) {
  if (daily.isEmpty) return ForecastSummary.empty;

  var total = 0.0;
  WeatherDay? wettest;
  double wettestMm =
      -1; // sentinel so 0.0 mm can still win if it's the only day
  WeatherDay? highestProbDay;
  int highestProb = -1;
  var measurableDays = 0;

  for (final day in daily) {
    final mm = dailyPrecipitationMm(day);
    total += mm;

    if (_hasNumericPrecipitation(day) && mm > wettestMm) {
      wettestMm = mm;
      wettest = day;
    }

    final prob = day.precipitationProbabilityMaxPct;
    if (prob != null && prob > highestProb) {
      highestProb = prob;
      highestProbDay = day;
    }

    if (mm > 0.0) measurableDays++;
  }

  return ForecastSummary(
    totalPrecipitationMm: total,
    wettestDay: wettest,
    wettestDayPrecipitationMm: wettest == null ? 0.0 : wettestMm,
    highestProbabilityDay: highestProbDay,
    highestProbabilityPct: highestProbDay == null ? null : highestProb,
    daysWithMeasurablePrecipitation: measurableDays,
    dayCount: daily.length,
  );
}
