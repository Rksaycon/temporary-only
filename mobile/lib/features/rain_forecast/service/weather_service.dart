/// Abstract network service for external weather sources.
library;

///
/// This is the single seam to swap Open-Meteo for a different provider with
/// zero UI changes. The repository operates on this interface.

import '../models/weather_data_models.dart';
import '../types.dart';

abstract class WeatherService {
  Future<WeatherForecastData> fetchDailyRainForecast(Location location);

  Future<WeatherForecastData> fetchHourlyForecast(Location location);

  Future<WeatherForecastData> fetchCurrentObservations(Location location);

  Future<WeatherForecastData> fetchGeoTelemetry(Location location);

  /// Convenience: fetch everything in one call, returning the most recent
  /// complete snapshot. Implementations may fetch daily + hourly + current in
  /// parallel and merge into a single [WeatherForecastData].
  Future<WeatherForecastData> fetchForecastSnapshot(Location location);
}

/// Categories used to classify a [WeatherApiException].
enum WeatherApiCategory {
  networkError,
  timeout,
  serverError,
  invalidResponse,
  unavailable,
}

/// Thrown when a weather source fails.
class WeatherApiException implements Exception {
  final String message;
  final WeatherApiCategory category;
  final dynamic raw;

  const WeatherApiException(this.message,
      {this.category = WeatherApiCategory.serverError, this.raw});

  @override
  String toString() => 'WeatherApiException: $message (category: $category)';
}
