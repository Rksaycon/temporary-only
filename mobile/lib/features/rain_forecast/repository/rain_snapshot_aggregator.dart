/// Aggregates repository data into a single transparent risk snapshot.
library;

import '../models/weather_risk_models.dart';
import '../models/weather_data_models.dart';
import '../types.dart';

/// Builds a [FloodRiskSnapshot] from the raw repository values.
///
/// Classification rules (kept visible in [WeatherRiskRules]):
///  - rain outlook is derived solely from precipitation_sum / rain_sum /
///    precipitation_probability, never from advisory or water data;
///  - official advisory comes only from the [OfficialFloodAdvisory] source;
///  - measured water comes only from [WaterLevelReading], and is clearly
///    flagged so it is never presented as a rainfall number.
FloodRiskSnapshot buildSnapshot({
  required Location location,
  required CurrentWeather? currentWeather,
  required List<WeatherDay> dailyRain,
  required List<WeatherHour>? hourlyDetails,
  required bool isStale,
  required String staleSince,
  required String? rainOutlookSummary,
  required double? expectedPrecipitationNext7dMm,
  required double? maxDailyPrecipitationMm,
  required double? maxDailyPrecipitationProbabilityPct,
  required OfficialFloodAdvisory? officialAdvisory,
  required WaterLevelReading? measuredWaterLevel,
  required WaterLevelForecast? predictedWaterLevel,
  required bool waterLevelSourceUnavailable,
}) {
  final hasRain =
      dailyRain.isNotEmpty || currentWeather?.hasObservation == true;
  final hasRainForecast = dailyRain.any((d) => d.hasRainfall);

  // Max daily precipitation for the 7-day outlook (rainfall only).
  final maxRainMm = dailyRain
      .map((d) => d.precipitationSumMm ?? d.rainSumMm ?? d.showersSumMm)
      .whereType<double>()
      .reduce((a, b) => a > b ? a : b)
      .clamp(0, double.infinity)
      .toDouble();

  // Max daily probability for the 7-day outlook.
  final maxPct = dailyRain
      .map((d) => d.precipitationProbabilityMaxPct)
      .whereType<int>()
      .reduce((a, b) => a > b ? a : b)
      .clamp(0, 100);

  // Mode from the official advisory, if present.
  String? advisoryStatus;
  if (officialAdvisory != null) {
    advisoryStatus = officialAdvisory.status;
  }

  // Measured water level status from the actual gauge, if present.
  String? waterStatus;
  final reading = measuredWaterLevel;
  if (reading != null && reading.hasLevel) {
    final level = reading.levelMeters!;
    final threshold = reading.officialWarningThresholdMeters;
    if (threshold != null) {
      final th = double.parse(threshold);
      waterStatus = level >= th ? 'ELEVATED' : 'NORMAL';
    } else {
      waterStatus = 'MEASURED';
    }
  }

  return FloodRiskSnapshot(
    location: location,
    currentWeather: currentWeather,
    dailyRain: dailyRain,
    hourlyDetails: hourlyDetails,
    isStale: isStale,
    staleSince: staleSince,
    rainOutlookSummary: rainOutlookSummary,
    expectedPrecipitationNext7dMm: expectedPrecipitationNext7dMm,
    maxDailyPrecipitationMm: maxRainMm,
    maxDailyPrecipitationProbabilityPct: maxPct.toDouble(),
    officialAdvisory: officialAdvisory,
    measuredWaterLevel: measuredWaterLevel,
    predictedWaterLevel: predictedWaterLevel,
    waterLevelSourceUnavailable: waterLevelSourceUnavailable,
    hasAnyRiskData: hasRain ||
        advisoryStatus != null ||
        waterStatus != null ||
        predictedWaterLevel?.hasForecast == true,
  );
}
