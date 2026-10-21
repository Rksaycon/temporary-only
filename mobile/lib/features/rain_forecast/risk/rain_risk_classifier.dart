/// Centralized classifier that converts raw rain data into transparent labels.
library;

///
/// This class is explicit about the source each label comes from:
///  - RAIN only from precipitation/probability
///  - ADVISORY only from official text
///  - WATER only from a real river measurement
///
/// It never produces a river height, never presents mm as m, and never merges
/// separate sources into a single synthetic value unless an explicit rule is
/// provided.
import '../models/weather_data_models.dart';
import '../models/weather_risk_models.dart';
import '../risk/weather_risk_rules.dart';
import '../types.dart';

/// Classifies rain forecast data into a transparent risk level.
class RainRiskClassifier {
  /// Classify a 7-day daily rain outlook into a label.
  static RiskRule classifyRainOutlook({
    required List<WeatherDay> daily,
    required Location location,
  }) {
    if (daily.isEmpty) {
      return const RiskRule(
        category: 'rain',
        type: 'outlook',
        label: 'Unavailable',
        isRainfallOnly: true,
      );
    }

    final anyRain = daily.any((d) => d.hasRainfall);
    final anyProbability =
        daily.any((d) => d.precipitationProbabilityMaxPct != null);

    if (!anyRain && !anyProbability) {
      return const RiskRule(
        category: 'rain',
        type: 'outlook',
        label: 'No measurable rain expected',
        isRainfallOnly: true,
      );
    }

    // Combine probability thresholds across days to get the day with the
    // highest risk, then classify the whole outlook using that.
    final maxProb = daily
        .map((d) => d.precipitationProbabilityMaxPct)
        .whereType<int>()
        .reduce((a, b) => a > b ? a : b);

    if (maxProb >= RainOutlay.highRainPct) {
      return RiskRule(
        category: 'rain',
        type: 'outlook',
        label: 'High rain expected',
        isRainfallOnly: true,
      );
    }
    if (maxProb >= RainOutlay.moderateRainPct) {
      return RiskRule(
        category: 'rain',
        type: 'outlook',
        label: 'Moderate rain expected',
        isRainfallOnly: true,
      );
    }
    if (maxProb >= RainOutlay.lowRainPct) {
      return RiskRule(
        category: 'rain',
        type: 'outlook',
        label: 'Low rain possible',
        isRainfallOnly: true,
      );
    }

    // If only a few days have small rain amounts, classify as low.
    final highProbDays = daily
        .where((d) =>
            d.precipitationProbabilityMaxPct != null &&
            d.precipitationProbabilityMaxPct! >= 60)
        .length;
    if (highProbDays > 0) {
      return RiskRule(
        category: 'rain',
        type: 'outlook',
        label: 'Isolated heavy rain possible',
        isRainfallOnly: true,
      );
    }

    return const RiskRule(
      category: 'rain',
      type: 'outlook',
      label: 'Light rain possible',
      isRainfallOnly: true,
    );
  }

  /// Classify a measured river stage against a warning threshold.
  static RiskRule classifyMeasuredWater({
    required double levelMeters,
    required WaterLevelReading reading,
  }) {
    if (reading.hasThreshold) {
      final threshold = double.parse(reading.officialWarningThresholdMeters!);
      if (levelMeters >= threshold) {
        return RiskRule(
          category: 'water',
          type: 'reading',
          label: 'Elevated',
          isRainfallOnly: false,
        );
      }
    }
    return const RiskRule(
      category: 'water',
      type: 'reading',
      label: 'Normal',
      isRainfallOnly: false,
    );
  }

  /// Build a source-status classification for the UI without any numeric
  /// fusion of rainfall and water.
  static String sourceStatusText({
    required Location location,
    required bool waterLevelSourceUnavailable,
    required bool hasOfficialAdvisory,
    required FloodRiskSnapshot snapshot,
  }) {
    if (waterLevelSourceUnavailable) {
      return SummaryText.waterSourceUnavailable(
          locationName: location.displayName);
    }
    if (hasOfficialAdvisory) {
      return SummaryText.hasAdvisory(locationName: location.displayName);
    }
    if (snapshot.measuredWaterLevel?.hasLevel == true) {
      return SummaryText.measuredWaterSafe(locationName: location.displayName);
    }
    return SummaryText.noAdvisory(locationName: location.displayName);
  }
}
