/// Core weather models produced by the Open-Meteo forecast API.
///
/// All values come straight from the provider. The models are deliberately
/// nullable so every malformed/partial response is represented exactly, and
/// the repository layer decides which fields are required for a "usable"
/// snapshot. No field is ever coerced into a fake value.
library;

import 'package:flutter/foundation.dart';

import '../types.dart';

/// A single ISO day returned by the daily forecast.
@immutable
class WeatherDay {
  final String time;
  final int? temperatureMaxC;
  final int? temperatureMinC;
  final double? precipitationSumMm;
  final double? rainSumMm;
  final double? showersSumMm;
  final int? precipitationProbabilityMaxPct;
  final int? weatherCode;
  final String? windSpeedMaxKmh;

  const WeatherDay({
    required this.time,
    this.temperatureMaxC,
    this.temperatureMinC,
    this.precipitationSumMm,
    this.rainSumMm,
    this.showersSumMm,
    this.precipitationProbabilityMaxPct,
    this.weatherCode,
    this.windSpeedMaxKmh,
  });

  bool get hasRainfall =>
      precipitationSumMm != null || rainSumMm != null || showersSumMm != null;

  bool get hasTemperature => temperatureMaxC != null || temperatureMinC != null;

  bool get hasProbability => precipitationProbabilityMaxPct != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WeatherDay && time == other.time;

  @override
  int get hashCode => time.hashCode;
}

/// One hourly bucket from the Open-Meteo hourly forecast.
@immutable
class WeatherHour {
  final String time;
  final double? precipitationMm;
  final double? rainMm;
  final double? showersMm;
  final double? precipitationProbabilityPct;
  final int? weatherCode;
  final double? windSpeedKmh;

  const WeatherHour({
    required this.time,
    this.precipitationMm,
    this.rainMm,
    this.showersMm,
    this.precipitationProbabilityPct,
    this.weatherCode,
    this.windSpeedKmh,
  });

  bool get hasPrecipitation =>
      precipitationMm != null || rainMm != null || showersMm != null;

  bool get hasRain => rainMm != null || showersMm != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WeatherHour && time == other.time;

  @override
  int get hashCode => time.hashCode;
}

/// Open-Meteo `current` block (actual observations from the `realtime` layer).
@immutable
class CurrentWeather {
  final double? temperatureC;
  final int? weatherCode;
  final double? windSpeedKmh;
  final double? precipitationMm;
  final double? relativeHumidityPct;
  final String? time;

  const CurrentWeather({
    this.temperatureC,
    this.weatherCode,
    this.windSpeedKmh,
    this.precipitationMm,
    this.relativeHumidityPct,
    this.time,
  });

  bool get hasObservation => temperatureC != null || weatherCode != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CurrentWeather && time == other.time;

  @override
  int get hashCode => time.hashCode;
}

/// The complete parsed response from Open-Meteo's forecast endpoint.
@immutable
class WeatherForecastData {
  final Location location;
  final String sourceUrl;
  final String callStartedAt;
  final String callFinishedAt;
  final CurrentWeather? current;
  final List<WeatherDay> daily;
  final List<WeatherHour> hourly;
  final Map<String, dynamic> raw; // keep the raw JSON for debug/tests

  const WeatherForecastData({
    required this.location,
    required this.sourceUrl,
    required this.callStartedAt,
    required this.callFinishedAt,
    this.current,
    required this.daily,
    required this.hourly,
    required this.raw,
  });

  int get dayCount => daily.length;

  int get hourCount => hourly.length;

  WeatherDay? dayFor(String isoDate) =>
      daily.firstWhereOrNull((d) => d.time == isoDate);

  WeatherHour? hourFor(String isoDate) =>
      hourly.firstWhereOrNull((h) => h.time == isoDate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherForecastData &&
          location == other.location &&
          sourceUrl == other.sourceUrl &&
          callStartedAt == other.callStartedAt &&
          callFinishedAt == other.callFinishedAt &&
          current == other.current &&
          daily == other.daily &&
          hourly == other.hourly;

  @override
  int get hashCode => Object.hash(
        location,
        sourceUrl,
        callStartedAt,
        callFinishedAt,
        current,
        daily,
        hourly,
      );
}

/// Extension so we can use `firstWhereOrNull` without depending on
/// `collection`. Works for any list element type.
extension NullableLookup<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
