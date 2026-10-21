/// Maps Open-Meteo WMO weather interpretation codes to an icon + a plain
/// description. Codes follow the WMO 4677 standard used by Open-Meteo.
///
/// Kept separate from the widget so it is trivially unit-testable and the UI
/// never has to hardcode a code table inline.
library;

import 'package:flutter/material.dart';

@immutable
class WeatherDescriptor {
  final IconData icon;
  final String description;

  const WeatherDescriptor(this.icon, this.description);
}

/// Returns an icon + human description for a WMO weather code.
///
/// An unknown/null code yields a neutral "—" so a malformed API value is
/// never presented as a fabricated condition.
WeatherDescriptor describeWeatherCode(int? code) {
  switch (code) {
    case 0:
      return const WeatherDescriptor(Icons.wb_sunny_rounded, 'Clear sky');
    case 1:
      return const WeatherDescriptor(Icons.wb_sunny_outlined, 'Mainly clear');
    case 2:
      return const WeatherDescriptor(Icons.wb_cloudy_rounded, 'Partly cloudy');
    case 3:
      return const WeatherDescriptor(Icons.cloud_rounded, 'Overcast');
    case 45:
    case 48:
      return const WeatherDescriptor(Icons.foggy, 'Fog');
    case 51:
    case 53:
    case 55:
      return const WeatherDescriptor(Icons.grain_rounded, 'Light drizzle');
    case 56:
    case 57:
      return const WeatherDescriptor(Icons.grain_rounded, 'Freezing drizzle');
    case 61:
      return const WeatherDescriptor(Icons.water_drop_rounded, 'Light rain');
    case 63:
      return const WeatherDescriptor(Icons.umbrella_rounded, 'Moderate rain');
    case 65:
      return const WeatherDescriptor(Icons.thunderstorm_rounded, 'Heavy rain');
    case 66:
    case 67:
      return const WeatherDescriptor(Icons.ac_unit_rounded, 'Freezing rain');
    case 71:
    case 73:
    case 75:
      return const WeatherDescriptor(Icons.snowing, 'Snow fall');
    case 77:
      return const WeatherDescriptor(Icons.snowing, 'Snow grains');
    case 80:
      return const WeatherDescriptor(Icons.water_drop_rounded, 'Light showers');
    case 81:
      return const WeatherDescriptor(Icons.umbrella_rounded, 'Rain showers');
    case 82:
      return const WeatherDescriptor(
          Icons.thunderstorm_rounded, 'Violent showers');
    case 85:
    case 86:
      return const WeatherDescriptor(Icons.snowing, 'Snow showers');
    case 95:
      return const WeatherDescriptor(
          Icons.thunderstorm_rounded, 'Thunderstorm');
    case 96:
    case 99:
      return const WeatherDescriptor(
          Icons.thunderstorm_rounded, 'Thunderstorm with hail');
    default:
      return const WeatherDescriptor(Icons.help_outline_rounded, '—');
  }
}
