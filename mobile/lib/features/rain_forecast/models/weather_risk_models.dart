/// Transparent risk-classification domain models.
///
/// The distinction this file enforces is the core requirement of the RFC:
/// "Weather and rainfall outlook", "Official flood advisories", "Measured river
/// water levels", and "Model-generated flood-risk estimates" are separate
/// sources. They are never merged into one synthetic "flood risk" value unless
/// an explicit, documented rule says so.
library;

import 'package:flutter/foundation.dart';

import '../types.dart';
import 'weather_data_models.dart';

/// A published or reported observed water measurement.
@immutable
class WaterLevelReading {
  final String station;
  final String riverName;
  final String locationName;
  final double latitude;
  final double longitude;
  final double? levelMeters;
  final String? measurementTimestamp;
  final String? source;
  final String? observationStatus;
  final String? officialWarningThresholdMeters;
  final Map<String, dynamic> raw;

  const WaterLevelReading({
    required this.station,
    required this.riverName,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    this.levelMeters,
    this.measurementTimestamp,
    this.source,
    this.observationStatus,
    this.officialWarningThresholdMeters,
    required this.raw,
  });

  bool get hasLevel => levelMeters != null;

  bool get hasThreshold => officialWarningThresholdMeters != null;

  String get levelDisplay {
    final level = levelMeters;
    if (level == null) return 'No reading available';
    return '${level.toStringAsFixed(2)} m';
  }
}

/// Official advisory metadata pulled from a verified government feed.
///
/// This is deliberately self-contained: nothing here is a river height. The
/// UI must never render this as a sensor measurement.
@immutable
class OfficialFloodAdvisory {
  final String id;
  final String source;
  final String title;
  final String status;
  final String issuedAt;
  final String? expiresAt;
  final String? description;
  final Map<String, dynamic> raw;

  const OfficialFloodAdvisory({
    required this.id,
    required this.source,
    required this.title,
    required this.status,
    required this.issuedAt,
    this.expiresAt,
    this.description,
    required this.raw,
  });
}

/// Hydrological/forecast output that comes from a validated model or an
/// official river-stage forecast feed.
@immutable
class WaterLevelForecast {
  final String station;
  final String riverName;
  final double? forecastedLevelMeters;
  final String? forecastIssuedAt;
  final String? forecastHorizon;
  final String? source;
  final Map<String, dynamic> raw;

  const WaterLevelForecast({
    required this.station,
    required this.riverName,
    this.forecastedLevelMeters,
    this.forecastIssuedAt,
    this.forecastHorizon,
    this.source,
    required this.raw,
  });

  bool get hasForecast => forecastedLevelMeters != null;

  String get forecastDisplay {
    final level = forecastedLevelMeters;
    if (level == null) return 'No forecast available';
    return '${level.toStringAsFixed(2)} m';
  }
}

/// The complete aggregated flood-risk snapshot returned to the UI.
@immutable
class FloodRiskSnapshot {
  final Location location;
  final CurrentWeather? currentWeather;
  final List<WeatherDay> dailyRain;
  final List<WeatherHour>? hourlyDetails;
  final bool isStale;
  final String staleSince;

  // Weather-source risk fields
  final String? rainOutlookSummary;
  final double? expectedPrecipitationNext7dMm;
  final double? maxDailyPrecipitationMm;
  final double? maxDailyPrecipitationProbabilityPct;

  // Official advisory (never a river height)
  final OfficialFloodAdvisory? officialAdvisory;

  // Measured river water (source that genuinely reports levels)
  final WaterLevelReading? measuredWaterLevel;

  // Model-generated forecast (only when supplied by a validated source)
  final WaterLevelForecast? predictedWaterLevel;

  final bool waterLevelSourceUnavailable;
  final bool hasAnyRiskData;

  const FloodRiskSnapshot({
    required this.location,
    this.currentWeather,
    required this.dailyRain,
    this.hourlyDetails,
    this.isStale = false,
    this.staleSince = '',
    this.rainOutlookSummary,
    this.expectedPrecipitationNext7dMm,
    this.maxDailyPrecipitationMm,
    this.maxDailyPrecipitationProbabilityPct,
    this.officialAdvisory,
    this.measuredWaterLevel,
    this.predictedWaterLevel,
    this.waterLevelSourceUnavailable = false,
    this.hasAnyRiskData = false,
  });

  bool get hasRainData =>
      dailyRain.isNotEmpty || currentWeather?.hasObservation == true;

  bool get hasRainForecast => dailyRain.any((d) => d.hasRainfall);

  bool get hasMeasuredWaterLevel => measuredWaterLevel?.hasLevel == true;

  bool get hasForecastWaterLevel => predictedWaterLevel?.hasForecast == true;

  bool get hasOfficialAdvisory => officialAdvisory != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FloodRiskSnapshot &&
          location == other.location &&
          currentWeather == other.currentWeather &&
          dailyRain == other.dailyRain &&
          hourlyDetails == other.hourlyDetails &&
          isStale == other.isStale &&
          staleSince == other.staleSince &&
          rainOutlookSummary == other.rainOutlookSummary &&
          expectedPrecipitationNext7dMm ==
              other.expectedPrecipitationNext7dMm &&
          maxDailyPrecipitationMm == other.maxDailyPrecipitationMm &&
          maxDailyPrecipitationProbabilityPct ==
              other.maxDailyPrecipitationProbabilityPct &&
          officialAdvisory == other.officialAdvisory &&
          measuredWaterLevel == other.measuredWaterLevel &&
          predictedWaterLevel == other.predictedWaterLevel &&
          waterLevelSourceUnavailable == other.waterLevelSourceUnavailable &&
          hasAnyRiskData == other.hasAnyRiskData;

  @override
  int get hashCode => Object.hash(
        location,
        currentWeather,
        dailyRain,
        hourlyDetails,
        isStale,
        staleSince,
        rainOutlookSummary,
        expectedPrecipitationNext7dMm,
        maxDailyPrecipitationMm,
        maxDailyPrecipitationProbabilityPct,
        officialAdvisory,
        measuredWaterLevel,
        predictedWaterLevel,
        waterLevelSourceUnavailable,
        hasAnyRiskData,
      );
}
