import 'package:flutter/foundation.dart';

/// Centralized rules for classifying rain and flood risk.
///

/// Centralized rules for classifying rain and flood risk.
///
/// This module intentionally keeps the two source kinds separate:
///  - RAIN (derived from Open-Meteo precipitation + probability)
///  - ADVISORY (official text advisories: no river height)
///  - WATER (measured river stage: true, checkable measurement)
///
/// No value is ever labeled as a river height unless the source is explicitly
/// a river-stage reading.

/// A single rule that maps raw inputs to a transparent classification.
@immutable
class RiskRule {
  final String category; // rain | advisory | water
  final String type; // outlook | advisory | reading | forecast
  final String label;
  final bool isRainfallOnly;

  const RiskRule({
    required this.category,
    required this.type,
    required this.label,
    this.isRainfallOnly = false,
  });
}

/// Approx. mm per hour thresholds -> risk label for rain.
class RainIntensity {
  static const int none = 0;
  static const int light = 1;
  static const int moderate = 5;
  static const int heavy = 15;
}

/// Precipitation-probability thresholds (%) used to label the rain outlook.
///
/// Kept here so the classifier and the repository summary share one source of
/// truth for what counts as low / moderate / high rain probability.
class RainOutlay {
  static const int lowRainPct = 30;
  static const int moderateRainPct = 60;
  static const int highRainPct = 80;
}

/// Plain-English summary explanations so the UI can always say why a label
/// was chosen (no opaque magic).
class SummaryText {
  static String noRain({required String locationName}) =>
      '$locationName: No measurable rain expected in the next 7 days.';

  static String lowRain({required String locationName}) =>
      '$locationName: Light rain possible on a few days; not expected to cause runoff issues.';

  static String moderateRain({required String locationName}) =>
      '$locationName: Moderate rainfall expected; watch low-lying areas and small streams.';

  static String highRain({required String locationName}) =>
      '$locationName: Heavy rainfall expected over several days; elevated runoff and flash-flood potential.';

  static String severeRain({required String locationName}) =>
      '$locationName: Very heavy rainfall expected; flooding is possible. Follow official alerts.';

  static String unknown({required String locationName}) =>
      '$locationName: Rain forecast unavailable right now.';

  static String noAdvisory({required String locationName}) =>
      '$locationName: No official flood advisory is currently active.';

  static String hasAdvisory({required String locationName}) =>
      '$locationName: An official flood advisory is active. Monitor local authorities.';

  static String measuredWaterSafe({required String locationName}) =>
      '$locationName: Measured river stage is within normal range.';

  static String measuredWaterWarning({required String locationName}) =>
      '$locationName: Measured river stage is near a warning threshold. Stay alert.';

  static String measuredWaterDanger({required String locationName}) =>
      '$locationName: Measured river stage is elevated. Move to higher ground.';

  static String waterSourceUnavailable({required String locationName}) =>
      '$locationName: River gauge data is not available from the source yet.';
}
