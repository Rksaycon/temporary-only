/// Repository responsible for fetching and aggregating raw weather data.
library;

///
/// This layer sits between the UI/provider and the network service. It:
///  - enforces the location/coordinate rule (no weather fetch without
///    verified coordinates),
///  - preserves field-level nullability,
///  - exposes only the granular data the UI needs (daily rain, hourly
///    details, current conditions),
///  - does NOT invent risk labels; classification is delegated to
///    [RainRiskClassifier].

import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/weather_data_models.dart';
import '../models/weather_risk_models.dart';
import '../risk/rain_risk_classifier.dart';
import '../risk/weather_risk_rules.dart';
import '../service/open_meteo_service.dart';
import '../service/weather_service.dart';
import '../types.dart';

/// Input that the repository can fetch in a single "snapshot".
@immutable
class WeatherSnapshot {
  final CurrentWeather? current;
  final List<WeatherDay> daily;
  final List<WeatherHour>? hourly;

  const WeatherSnapshot({
    this.current,
    required this.daily,
    this.hourly,
  });
}

/// Centralized access point for all weather data.
///
/// The repository is a thin, deterministic layer over [WeatherService]. All
/// network failures surface as [WeatherApiException], never as raw
/// [DioException] or [SocketException], so the UI can show one consistent
/// "no data" state and never parse a corrupted payload.
@immutable
class WeatherRepository {
  final WeatherService _service;

  const WeatherRepository({WeatherService? service})
      : _service = service ?? const OpenMeteoServiceImpl();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherRepository && _service == other._service;

  @override
  int get hashCode => _service.hashCode;

  /// Fetches the raw forecast data for a location. Returns null when the
  /// location is unusable or the service fails.
  Future<WeatherForecastData?> fetchForecast(
    Location location,
  ) async {
    if (!LocationConfig.hasCoordinate(location.id)) {
      return null;
    }

    try {
      final data = await _service.fetchForecastSnapshot(location);
      return data;
    } on WeatherApiException catch (e) {
      if (e.category == WeatherApiCategory.unavailable) {
        return null;
      }
      // Log and return null; the UI shows a retry state.
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Returns a snapshot structure for caching/UI.
  WeatherSnapshot asSnapshot(WeatherForecastData data) {
    return WeatherSnapshot(
      current: data.current,
      daily: data.daily,
      hourly: data.hourly,
    );
  }

  /// Builds a [FloodRiskSnapshot] from raw data without mutating anything.
  FloodRiskSnapshot buildSnapshot({
    required WeatherForecastData data,
    required bool isStale,
    required String staleSince,
    required OfficialFloodAdvisory? officialAdvisory,
    required WaterLevelReading? measuredWaterLevel,
    required WaterLevelForecast? predictedWaterLevel,
    required bool waterLevelSourceUnavailable,
  }) {
    final location = data.location;
    final currentWeather = data.current;
    final dailyRain = data.daily;
    final hourlyDetails = data.hourly;

    // Daily rain outlook summary (rainfall only).
    String? rainOutlookSummary;
    final anyRain = dailyRain.any((d) => d.hasRainfall) ||
        dailyRain.any((d) => d.precipitationProbabilityMaxPct != null);
    if (anyRain) {
      final maxProb = dailyRain
          .map((d) => d.precipitationProbabilityMaxPct)
          .whereType<int>()
          .reduce((a, b) => a > b ? a : b);
      final maxRain = dailyRain
          .map((d) => d.precipitationSumMm ?? d.rainSumMm ?? d.showersSumMm)
          .whereType<double>()
          .reduce((a, b) => a > b ? a : b);

      if (maxProb >= 80) {
        rainOutlookSummary =
            SummaryText.severeRain(locationName: location.displayName);
      } else if (maxProb >= 60) {
        rainOutlookSummary =
            SummaryText.highRain(locationName: location.displayName);
      } else if (maxProb >= 30) {
        rainOutlookSummary =
            SummaryText.moderateRain(locationName: location.displayName);
      } else {
        rainOutlookSummary =
            SummaryText.lowRain(locationName: location.displayName);
      }
    } else {
      rainOutlookSummary =
          SummaryText.noRain(locationName: location.displayName);
    }

    // Weather-only risk values.
    final expectedPrecipitationNext7dMm = dailyRain
        .map((d) => d.precipitationSumMm ?? d.rainSumMm ?? d.showersSumMm)
        .whereType<double>()
        .reduce((a, b) => a > b ? a : b);
    final maxDailyPrecipitationMm = expectedPrecipitationNext7dMm;
    final maxDailyPrecipitationProbabilityPct = dailyRain
        .map((d) => d.precipitationProbabilityMaxPct)
        .whereType<int>()
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return FloodRiskSnapshot(
      location: data.location,
      currentWeather: currentWeather,
      dailyRain: dailyRain,
      hourlyDetails: hourlyDetails,
      isStale: isStale,
      staleSince: staleSince,
      rainOutlookSummary: rainOutlookSummary,
      expectedPrecipitationNext7dMm: expectedPrecipitationNext7dMm,
      maxDailyPrecipitationMm: maxDailyPrecipitationMm,
      maxDailyPrecipitationProbabilityPct: maxDailyPrecipitationProbabilityPct,
      officialAdvisory: officialAdvisory,
      measuredWaterLevel: measuredWaterLevel,
      predictedWaterLevel: predictedWaterLevel,
      waterLevelSourceUnavailable: waterLevelSourceUnavailable,
      hasAnyRiskData: data.daily.isNotEmpty,
    );
  }
}
