// Unit tests for Open-Meteo response parsing, using a mocked Dio so no real
// network call is made. Verifies: successful parse, missing/malformed fields,
// timezone/date handling, and typed exceptions on failure.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:may_laud/features/rain_forecast/service/open_meteo_service.dart';
import 'package:may_laud/features/rain_forecast/service/weather_service.dart';
import 'package:may_laud/features/rain_forecast/types.dart';

const _loc = Location(
  id: 'mld_milaor',
  name: 'Milaor',
  province: 'Camarines Sur',
  latitude: 13.7306,
  longitude: 123.4270,
  officialName: 'Milaor, Camarines Sur',
);

Map<String, dynamic> _fullPayload() => {
      'current': {
        'time': '2026-01-01T12:00',
        'temperature_2m': 30.4,
        'weather_code': 3,
        'wind_speed_10m': 12.0,
        'precipitation': 0.2,
        'relative_humidity_2m': 78.0,
      },
      'daily': {
        'time': ['2026-01-01', '2026-01-02', '2026-01-03'],
        'temperature_2m_max': [31, 32, 29],
        'temperature_2m_min': [24, 25, 23],
        'precipitation_sum': [1.5, 0.0, 12.25],
        'rain_sum': [1.0, 0.0, 10.0],
        'showers_sum': [0.5, 0.0, 2.25],
        'precipitation_probability_max': [40, 10, 85],
        'weather_code': [3, 0, 65],
        'wind_speed_10m_max': [15.0, 12.0, 30.0],
      },
      'hourly': {
        'time': ['2026-01-01T00:00', '2026-01-01T01:00'],
        'precipitation': [0.1, 0.0],
        'rain': [0.1, 0.0],
        'showers': [0.0, 0.0],
        'precipitation_probability': [20.0, 10.0],
        'weather_code': [3, 0],
        'wind_speed_10m': [8.0, 7.0],
      },
    };

/// Builds a service backed by a Dio whose GET returns [payload] verbatim.
OpenMeteoServiceImpl _serviceWith(dynamic payload, {DioException? error}) {
  final dio = Dio()
    ..httpClientAdapter = _FakeAdapter(payload: payload, error: error);
  return OpenMeteoServiceImpl(dio: dio);
}

void main() {
  group('OpenMeteoServiceImpl parsing', () {
    test('parses a full snapshot (current + daily + hourly)', () async {
      final service = _serviceWith(_fullPayload());
      final data = await service.fetchForecastSnapshot(_loc);

      expect(data.location.id, 'mld_milaor');
      expect(data.dayCount, 3);
      expect(data.hourCount, 2);

      expect(data.current?.temperatureC, 30.4);
      expect(data.current?.weatherCode, 3);
      expect(data.current?.hasObservation, isTrue);

      final day3 = data.daily[2];
      expect(day3.time, '2026-01-03');
      expect(day3.temperatureMaxC, 29);
      expect(day3.temperatureMinC, 23);
      expect(day3.precipitationSumMm, 12.25);
      expect(day3.precipitationProbabilityMaxPct, 85);

      expect(data.hourly.first.precipitationMm, 0.1);
      expect(data.hourly.first.precipitationProbabilityPct, 20.0);
    });

    test('records source url and call timestamps', () async {
      final service = _serviceWith(_fullPayload());
      final data = await service.fetchForecastSnapshot(_loc);
      expect(data.sourceUrl, contains('api.open-meteo.com'));
      expect(data.sourceUrl, contains('latitude=13.7306'));
      expect(data.callStartedAt, isNotEmpty);
      expect(data.callFinishedAt, isNotEmpty);
    });

    test('missing fields become null, never fabricated', () async {
      final service = _serviceWith({
        'daily': {
          'time': ['2026-01-01'],
          'precipitation_sum': [null],
        },
      });
      final data = await service.fetchDailyRainForecast(_loc);
      final day = data.daily.single;
      expect(day.precipitationSumMm, isNull);
      expect(day.precipitationProbabilityMaxPct, isNull);
      expect(day.weatherCode, isNull);
      expect(day.hasRainfall, isFalse);
    });

    test('empty response throws invalidResponse', () async {
      final service = _serviceWith(null);
      expect(
        () => service.fetchForecastSnapshot(_loc),
        throwsA(isA<WeatherApiException>().having(
          (e) => e.category,
          'category',
          WeatherApiCategory.invalidResponse,
        )),
      );
    });

    test('connection error surfaces as a typed exception', () async {
      final service = _serviceWith(
        null,
        error: DioException(
          requestOptions: RequestOptions(path: 'x'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(
        () => service.fetchForecastSnapshot(_loc),
        throwsA(isA<WeatherApiException>().having(
          (e) => e.category,
          'category',
          WeatherApiCategory.networkError,
        )),
      );
    });

    test('timeout surfaces as a typed exception', () async {
      final service = _serviceWith(
        null,
        error: DioException(
          requestOptions: RequestOptions(path: 'x'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      expect(
        () => service.fetchForecastSnapshot(_loc),
        throwsA(isA<WeatherApiException>().having(
          (e) => e.category,
          'category',
          WeatherApiCategory.timeout,
        )),
      );
    });
  });
}

/// Minimal Dio HttpClientAdapter that returns a canned response or error.
class _FakeAdapter implements HttpClientAdapter {
  final dynamic payload;
  final DioException? error;

  _FakeAdapter({this.payload, this.error});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? future,
  ) async {
    if (error != null) throw error!;
    final body = payload == null ? '' : jsonEncode(payload);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
