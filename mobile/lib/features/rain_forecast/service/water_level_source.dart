/// Water-level data source abstraction.
///
/// The forecast feature deliberately keeps RIVER WATER LEVEL separate from
/// RAINFALL. A water-level value is a measured/predicted river height in
/// METERS and must never be derived from, or substituted by, rainfall in
/// MILLIMETERS (see `models/weather_risk_models.dart`).
///
/// This interface lets a verified government provider (e.g. a future
/// server-side PAGASA gauge feed) be plugged in without touching the UI.
library;

import 'package:flutter/foundation.dart';

import '../models/weather_risk_models.dart';
import '../types.dart';

/// Availability of a water-level source for a location.
enum WaterLevelAvailability {
  /// A verified reading/forecast/advisory was returned.
  available,

  /// No verified source publishes machine-readable river-stage data for the
  /// location. The UI shows an honest "unavailable" message and never invents
  /// a gauge value.
  unavailable,
}

/// The result of a water-level lookup for a location.
@immutable
class WaterLevelSnapshot {
  final WaterLevelAvailability availability;

  /// Measured river stage, only when supplied by a real gauge source.
  final WaterLevelReading? reading;

  /// Predicted river stage, only when supplied by a validated forecast model.
  final WaterLevelForecast? forecast;

  /// Official advisory text (never a river height), when published.
  final OfficialFloodAdvisory? advisory;

  /// A human-readable, source-honest status message.
  final String message;

  const WaterLevelSnapshot({
    required this.availability,
    this.reading,
    this.forecast,
    this.advisory,
    required this.message,
  });

  bool get isUnavailable => availability == WaterLevelAvailability.unavailable;
  bool get hasMeasuredLevel => reading?.hasLevel == true;
  bool get hasForecastLevel => forecast?.hasForecast == true;
  bool get hasAdvisory => advisory != null;
}

/// A pluggable source of river water-level information.
///
/// Implementations MUST:
///  - only report a level when it comes from a real gauge/forecast feed,
///  - never synthesize a meter value from rainfall,
///  - return [WaterLevelAvailability.unavailable] with a clear message when no
///    verified data exists for the location.
abstract class WaterLevelSource {
  Future<WaterLevelSnapshot> fetch(Location location);
}

/// Default implementation used today.
///
/// PAGASA's Flood Caster (https://floodcaster.pagasa.dost.gov.ph/) and the
/// public advisories page are web UIs, not documented public JSON APIs, and
/// scraping them would violate their terms and be unreliable. Until an
/// authorized, server-side feed is wired up, this source honestly reports that
/// river water-level forecasts are unavailable for the location while the
/// real 7-day RAINFALL forecast remains available.
///
/// To add a real provider later, implement [WaterLevelSource] and swap it into
/// `rain_forecast_provider.dart` (see docs/RAIN_FORECAST_FEATURE.md). Any
/// credentialed call must stay server-side — never embed a secret in the app.
class UnavailableWaterLevelSource implements WaterLevelSource {
  const UnavailableWaterLevelSource();

  @override
  Future<WaterLevelSnapshot> fetch(Location location) async {
    return WaterLevelSnapshot(
      availability: WaterLevelAvailability.unavailable,
      message: 'River water-level forecast unavailable for this location. '
          'No verified government gauge feed publishes machine-readable '
          'river-stage data for ${location.displayName} yet. The 7-day rainfall '
          'forecast above remains available and is the leading indicator for '
          'flood risk — please also monitor official PAGASA advisories.',
    );
  }
}
