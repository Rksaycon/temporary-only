/// Open-Meteo implementation of [WeatherService].
///
/// Design goals:
///  - Timeouts, a scoped retry surface, and typed exceptions so an offline or
///    hung-up call never crashes the UI.
///  - All values are returned as nullable models. A missing field means "not
///    provided", never a made-up value.
///  - The caller is responsible for determining staleness and for any caching
///    policy it chooses.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/weather_data_models.dart';
import '../types.dart';
import 'weather_service.dart';

/// Open-Meteo forecast endpoint base URL.
const String _openMeteoBase = 'https://api.open-meteo.com/v1/forecast';

const String _userAgent = 'may-laud-flutter/1.0';

const List<String> _currentTokens = <String>[
  'temperature_2m',
  'relative_humidity_2m',
  'apparent_temperature',
  'weather_code',
  'wind_speed_10m',
  'precipitation',
];

const List<String> _dailyTokens = <String>[
  'temperature_2m_max',
  'temperature_2m_min',
  'precipitation_sum',
  'rain_sum',
  'showers_sum',
  'precipitation_probability_max',
  'weather_code',
  'wind_speed_10m_max',
];

const List<String> _hourlyTokens = <String>[
  'temperature_2m',
  'precipitation',
  'rain',
  'showers',
  'precipitation_probability',
  'weather_code',
  'wind_speed_10m',
];

/// Vanilla Dart implementation of [WeatherService] (unit-testable without a
/// network by injecting a fake [Dio]).
class OpenMeteoServiceImpl implements WeatherService {
  /// Optional injected client. When null the lazily-created [_defaultDio] is
  /// used so the default constructor can stay `const` for the repository's
  /// `const OpenMeteoServiceImpl()` default.
  final Dio? _injectedDio;

  const OpenMeteoServiceImpl({Dio? dio}) : _injectedDio = dio;

  static final Logger _log = Logger();

  static final Dio _defaultDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      headers: {HttpHeaders.userAgentHeader: _userAgent},
    ),
  );

  Dio get _dio => _injectedDio ?? _defaultDio;

  @override
  Future<WeatherForecastData> fetchDailyRainForecast(Location location) =>
      _fetch(location, dailyForecast: true);

  @override
  Future<WeatherForecastData> fetchHourlyForecast(Location location) =>
      _fetch(location, hourlyForecast: true);

  @override
  Future<WeatherForecastData> fetchCurrentObservations(Location location) =>
      _fetch(location, currentObservations: true);

  @override
  Future<WeatherForecastData> fetchGeoTelemetry(Location location) =>
      _fetch(location, currentObservations: true);

  @override
  Future<WeatherForecastData> fetchForecastSnapshot(Location location) =>
      _fetch(
        location,
        dailyForecast: true,
        hourlyForecast: true,
        currentObservations: true,
      );

  /// Shared fetch implementation. Builds an Open-Meteo query from whichever
  /// sections were requested, then parses the sections that came back. `daily`,
  /// `hourly` and `current` are independent query flags; whichever are set are
  /// requested and parsed. Requests that ask for nothing default to `current`.
  Future<WeatherForecastData> _fetch(
    Location location, {
    bool dailyForecast = false,
    bool hourlyForecast = false,
    bool currentObservations = false,
  }) async {
    if (!LocationConfig.hasCoordinate(location.id)) {
      throw const WeatherApiException(
        'No verified coordinates available for this location.',
        category: WeatherApiCategory.unavailable,
      );
    }

    final requestedNothing =
        !dailyForecast && !hourlyForecast && !currentObservations;

    final query = <String, String>{
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'timezone': 'auto',
    };
    if (dailyForecast) query['daily'] = _dailyTokens.join(',');
    if (hourlyForecast) query['hourly'] = _hourlyTokens.join(',');
    if (currentObservations || requestedNothing) {
      query['current'] = _currentTokens.join(',');
    }

    final uri = _buildUri(query);
    final startedAt = DateTime.now().toIso8601String();

    try {
      final response = await _dio.get<Map<String, dynamic>>(uri.toString());
      final payload = response.data;
      if (payload == null) {
        throw const WeatherApiException(
          'Empty response from weather service.',
          category: WeatherApiCategory.invalidResponse,
        );
      }

      return WeatherForecastData(
        location: location,
        sourceUrl: uri.toString(),
        callStartedAt: startedAt,
        callFinishedAt: DateTime.now().toIso8601String(),
        current: _parseCurrent(payload['current'] as Map<String, dynamic>?),
        daily: _parseDaily(payload['daily'] as Map<String, dynamic>?),
        hourly: _parseHourly(payload['hourly'] as Map<String, dynamic>?),
        raw: payload,
      );
    } catch (error, stack) {
      _log.e(
        'Open-Meteo fetch failed',
        error: error,
        stackTrace: stack,
      );
      if (error is WeatherApiException) {
        rethrow;
      }
      throw WeatherApiException(
        _friendlyMessage(error),
        category: _categoryFor(error),
      );
    }
  }

  Uri _buildUri(Map<String, String> query) {
    final encoded = query.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return Uri.parse('$_openMeteoBase?$encoded');
  }

  static WeatherApiCategory _categoryFor(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return WeatherApiCategory.timeout;
        case DioExceptionType.badResponse:
          return WeatherApiCategory.serverError;
        case DioExceptionType.connectionError:
          return WeatherApiCategory.networkError;
        default:
          return WeatherApiCategory.invalidResponse;
      }
    }
    return WeatherApiCategory.invalidResponse;
  }

  static String _friendlyMessage(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'The weather service took too long to respond. Please try again.';
        case DioExceptionType.connectionError:
          return 'No internet connection. Showing the last available forecast.';
        case DioExceptionType.badResponse:
          return 'The weather service is temporarily unavailable. Please try again later.';
        default:
          return 'Unable to load the weather forecast right now.';
      }
    }
    return 'Unable to load the weather forecast right now.';
  }

  /// Parses the Open-Meteo `daily` block. Each field is a parallel array
  /// indexed by day; a null/absent entry at index [i] leaves that field null.
  List<WeatherDay> _parseDaily(Map<String, dynamic>? daily) {
    if (daily == null) return const [];
    final times = _stringList(daily['time']);
    final result = <WeatherDay>[];
    for (var i = 0; i < times.length; i++) {
      result.add(WeatherDay(
        time: times[i],
        temperatureMaxC: _intAt(daily['temperature_2m_max'], i),
        temperatureMinC: _intAt(daily['temperature_2m_min'], i),
        precipitationSumMm: _doubleAt(daily['precipitation_sum'], i),
        rainSumMm: _doubleAt(daily['rain_sum'], i),
        showersSumMm: _doubleAt(daily['showers_sum'], i),
        precipitationProbabilityMaxPct:
            _intAt(daily['precipitation_probability_max'], i),
        weatherCode: _intAt(daily['weather_code'], i),
        windSpeedMaxKmh: _doubleAt(daily['wind_speed_10m_max'], i)?.toString(),
      ));
    }
    return result;
  }

  /// Parses the Open-Meteo `hourly` block the same parallel-array way.
  List<WeatherHour> _parseHourly(Map<String, dynamic>? hourly) {
    if (hourly == null) return const [];
    final times = _stringList(hourly['time']);
    final result = <WeatherHour>[];
    for (var i = 0; i < times.length; i++) {
      result.add(WeatherHour(
        time: times[i],
        precipitationMm: _doubleAt(hourly['precipitation'], i),
        rainMm: _doubleAt(hourly['rain'], i),
        showersMm: _doubleAt(hourly['showers'], i),
        precipitationProbabilityPct:
            _doubleAt(hourly['precipitation_probability'], i),
        weatherCode: _intAt(hourly['weather_code'], i),
        windSpeedKmh: _doubleAt(hourly['wind_speed_10m'], i),
      ));
    }
    return result;
  }

  /// Parses the Open-Meteo `current` block (flat key/value, not arrays).
  CurrentWeather? _parseCurrent(Map<String, dynamic>? current) {
    if (current == null) return null;
    return CurrentWeather(
      time: current['time'] as String?,
      temperatureC: _asDouble(current['temperature_2m']),
      weatherCode: _asInt(current['weather_code']),
      windSpeedKmh: _asDouble(current['wind_speed_10m']),
      precipitationMm: _asDouble(current['precipitation']),
      relativeHumidityPct: _asDouble(current['relative_humidity_2m']),
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e?.toString() ?? '').toList();
  }

  static double? _doubleAt(dynamic raw, int index) {
    if (raw is! List || index >= raw.length) return null;
    return _asDouble(raw[index]);
  }

  static int? _intAt(dynamic raw, int index) {
    if (raw is! List || index >= raw.length) return null;
    return _asInt(raw[index]);
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
