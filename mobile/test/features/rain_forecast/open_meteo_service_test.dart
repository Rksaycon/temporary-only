// Unit tests for the rain_forecast feature.
//
// These tests exercise the Open-Meteo service with an injected fake [Dio] so
// no network is required, and they cover the parsing contract, the typed error
// handling, and the repository -> aggregator -> classifier flow.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:may_laud/features/rain_forecast/models/weather_data_models.dart';
import 'package:may_laud/features/rain_forecast/models/weather_risk_models.dart';
import 'package:may_laud/features/rain_forecast/repository/rain_snapshot_aggregator.dart';
import 'package:may_laud/features/rain_forecast/repository/weather_repository.dart';
import 'package:may_laud/features/rain_forecast/risk/rain_risk_classifier.dart';
import 'package:may_laud/features/rain_forecast/service/open_meteo_service.dart';
import 'package:may_laud/features/rain_forecast/service/weather_service.dart';
import 'package:may_laud/features/rain_forecast/types.dart';

/// Builds a real [Dio] whose [HttpClientAdapter] returns a canned response
/// body (or throws) for a single GET, so Dio's full pipeline still runs.
Dio _fakeDio({
  Object? body,
  int statusCode = 200,
  DioException? throws,
}) {
  final dio = Dio(BaseOptions());
  dio.httpClientAdapter = _FakeAdapter(
    body: body,
    statusCode: statusCode,
    throws: throws,
  );
  return dio;
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.body, this.statusCode = 200, this.throws});

  final Object? body;
  final int statusCode;
  final DioException? throws;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (throws != null) {
      throw throws!;
    }
    return ResponseBody.fromString(
      jsonEncode(body ?? <String, dynamic>{}),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A realistic Open-Meteo forecast payload for the assigned Milaor location.
Map<String, dynamic> _samplePayload() => {
      'latitude': 13.7306,
      'longitude': 123.427,
      'timezone': 'Asia/Manila',
      'current': {
        'time': '2026-10-14T09:00',
        'temperature_2m': 29.4,
        'relative_humidity_2m': 78,
        'weather_code': 3,
        'wind_speed_10m': 12.3,
        'precipitation': 0.0,
      },
      'daily': {
        'time': ['2026-10-14', '2026-10-15', '2026-10-16'],
        'temperature_2m_max': [31.2, 30.8, 32.0],
        'temperature_2m_min': [25.1, 24.9, 25.5],
        'precipitation_sum': [4.2, 12.6, 0.0],
        'rain_sum': [3.1, 11.2, 0.0],
        'showers_sum': [1.1, 1.4, 0.0],
        'precipitation_probability_max': [55, 82, 10],
        'weather_code': [61, 63, 0],
        'wind_speed_10m_max': [18.2, 22.5, 14.0],
      },
      'hourly': {
        'time': ['2026-10-14T00:00', '2026-10-14T01:00'],
        'precipitation': [0.1, 0.4],
        'rain': [0.0, 0.3],
        'showers': [0.1, 0.1],
        'precipitation_probability': [40, 65],
        'weather_code': [3, 61],
        'wind_speed_10m': [10.0, 11.5],
      },
    };
void main() {
  group('OpenMeteoServiceImpl parsing', () {
    test('fetchForecastSnapshot parses daily, hourly and current', () async {
      final service =
          OpenMeteoServiceImpl(dio: _fakeDio(body: _samplePayload()));

      final data = await service.fetchForecastSnapshot(assignedLocation);

      expect(data.location, assignedLocation);
      expect(data.sourceUrl, contains('api.open-meteo.com'));
      expect(data.callStartedAt, isNotEmpty);
      expect(data.callFinishedAt, isNotEmpty);

      expect(data.current, isNotNull);
      expect(data.current!.temperatureC, 29.4);
      expect(data.current!.weatherCode, 3);
      expect(data.current!.relativeHumidityPct, 78.0);
      expect(data.current!.hasObservation, isTrue);

      expect(data.dayCount, 3);
      final first = data.daily.first;
      expect(first.time, '2026-10-14');
      expect(first.temperatureMaxC, 31);
      expect(first.temperatureMinC, 25);
      expect(first.precipitationSumMm, 4.2);
      expect(first.rainSumMm, 3.1);
      expect(first.showersSumMm, 1.1);
      expect(first.precipitationProbabilityMaxPct, 55);
      expect(first.weatherCode, 61);
      expect(first.windSpeedMaxKmh, '18.2');
      expect(first.hasRainfall, isTrue);

      expect(data.dayFor('2026-10-15')!.precipitationProbabilityMaxPct, 82);
      expect(data.dayFor('1999-01-01'), isNull);

      expect(data.hourCount, 2);
      final h0 = data.hourly.first;
      expect(h0.time, '2026-10-14T00:00');
      expect(h0.precipitationMm, 0.1);
      expect(h0.rainMm, 0.0);
      expect(h0.showersMm, 0.1);
      expect(h0.precipitationProbabilityPct, 40.0);
      expect(h0.weatherCode, 3);
      expect(h0.windSpeedKmh, 10.0);
      expect(h0.hasRain, isTrue);

      expect(data.raw['timezone'], 'Asia/Manila');
    });

    test('missing sections parse to empty lists / null current', () async {
      final service = OpenMeteoServiceImpl(
        dio: _fakeDio(
          body: {
            'current': {'time': '2026-10-14T09:00', 'temperature_2m': 28.0},
          },
        ),
      );

      final data = await service.fetchCurrentObservations(assignedLocation);

      expect(data.daily, isEmpty);
      expect(data.hourly, isEmpty);
      expect(data.current!.temperatureC, 28.0);
    });

    test('partial daily arrays never fabricate values', () async {
      final service = OpenMeteoServiceImpl(
        dio: _fakeDio(
          body: {
            'daily': {
              'time': ['2026-10-14', '2026-10-15'],
              'precipitation_sum': [5.0, null],
            },
          },
        ),
      );

      final data = await service.fetchDailyRainForecast(assignedLocation);

      expect(data.dayCount, 2);
      expect(data.daily[0].precipitationSumMm, 5.0);
      expect(data.daily[0].temperatureMaxC, isNull);
      expect(data.daily[0].weatherCode, isNull);
      expect(data.daily[1].precipitationSumMm, isNull);
    });

    test('numeric strings are coerced, non-numeric stay null', () async {
      final service = OpenMeteoServiceImpl(
        dio: _fakeDio(
          body: {
            'daily': {
              'time': ['2026-10-14'],
              'precipitation_sum': ['3.5'],
              'temperature_2m_max': ['not-a-number'],
            },
          },
        ),
      );

      final data = await service.fetchDailyRainForecast(assignedLocation);
      expect(data.daily[0].precipitationSumMm, 3.5);
      expect(data.daily[0].temperatureMaxC, isNull);
    });
  });

  group('OpenMeteoServiceImpl error handling', () {
    test('network errors surface as WeatherApiException(networkError)',
        () async {
      final service = OpenMeteoServiceImpl(
        dio: _fakeDio(
          throws: DioException(
            requestOptions: RequestOptions(path: 'x'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      expect(
        () => service.fetchForecastSnapshot(assignedLocation),
        throwsA(
          isA<WeatherApiException>()
              .having((e) => e.category, 'category',
                  WeatherApiCategory.networkError)
              .having((e) => e.message, 'message', isNotEmpty),
        ),
      );
    });

    test('timeout errors surface as WeatherApiCategory.timeout', () async {
      final service = OpenMeteoServiceImpl(
        dio: _fakeDio(
          throws: DioException(
            requestOptions: RequestOptions(path: 'x'),
            type: DioExceptionType.connectionTimeout,
          ),
        ),
      );

      expect(
        () => service.fetchForecastSnapshot(assignedLocation),
        throwsA(isA<WeatherApiException>()
            .having((e) => e.category, 'category', WeatherApiCategory.timeout)),
      );
    });
  });

  group('WeatherRepository + aggregator + classifier', () {
    test('fetchForecast returns data for the assigned location', () async {
      final repo = WeatherRepository(
        service: OpenMeteoServiceImpl(dio: _fakeDio(body: _samplePayload())),
      );

      final data = await repo.fetchForecast(assignedLocation);
      expect(data, isNotNull);
      expect(data!.dayCount, 3);

      final snapshot = repo.asSnapshot(data);
      expect(snapshot.current!.temperatureC, 29.4);
      expect(snapshot.daily.length, 3);
      expect(snapshot.hourly!.length, 2);
    });

    test('fetchForecast returns null when the service throws', () async {
      final repo = WeatherRepository(
        service: OpenMeteoServiceImpl(
          dio: _fakeDio(
            throws: DioException(
              requestOptions: RequestOptions(path: 'x'),
              type: DioExceptionType.connectionError,
            ),
          ),
        ),
      );

      expect(await repo.fetchForecast(assignedLocation), isNull);
    });

    test('buildSnapshot produces a transparent FloodRiskSnapshot', () async {
      final repo = WeatherRepository(
        service: OpenMeteoServiceImpl(dio: _fakeDio(body: _samplePayload())),
      );
      final data = (await repo.fetchForecast(assignedLocation))!;

      final snap = buildSnapshot(
        location: assignedLocation,
        currentWeather: data.current,
        dailyRain: data.daily,
        hourlyDetails: data.hourly,
        isStale: false,
        staleSince: '',
        rainOutlookSummary: 'Heavy rainfall expected',
        expectedPrecipitationNext7dMm: 12.6,
        maxDailyPrecipitationMm: 12.6,
        maxDailyPrecipitationProbabilityPct: 82,
        officialAdvisory: null,
        measuredWaterLevel: null,
        predictedWaterLevel: null,
        waterLevelSourceUnavailable: true,
      );

      expect(snap.hasRainData, isTrue);
      expect(snap.hasRainForecast, isTrue);
      expect(snap.maxDailyPrecipitationMm, 12.6);
      expect(snap.maxDailyPrecipitationProbabilityPct, 82.0);
      // Water source is genuinely separate from rain data.
      expect(snap.hasMeasuredWaterLevel, isFalse);
      expect(snap.hasForecastWaterLevel, isFalse);
      expect(snap.waterLevelSourceUnavailable, isTrue);
    });

    test('classifier labels high-probability outlook as high rain', () {
      final daily = [
        WeatherDay(time: 'd0', precipitationProbabilityMaxPct: 55),
        WeatherDay(time: 'd1', precipitationProbabilityMaxPct: 82),
        WeatherDay(time: 'd2', precipitationProbabilityMaxPct: 10),
      ];

      final rule = RainRiskClassifier.classifyRainOutlook(
        daily: daily,
        location: assignedLocation,
      );
      expect(rule.category, 'rain');
      expect(rule.isRainfallOnly, isTrue);
      expect(rule.label, 'High rain expected');
    });

    test('classifier returns Unavailable for empty outlook', () {
      final rule = RainRiskClassifier.classifyRainOutlook(
        daily: const [],
        location: assignedLocation,
      );
      expect(rule.label, 'Unavailable');
    });

    test('measured water is classified only against its own threshold', () {
      final reading = WaterLevelReading(
        station: 'test-gauge',
        riverName: 'Test River',
        locationName: 'Milaor',
        latitude: 13.7306,
        longitude: 123.427,
        levelMeters: 3.2,
        officialWarningThresholdMeters: '3.0',
        raw: const {},
      );

      final rule = RainRiskClassifier.classifyMeasuredWater(
        levelMeters: 3.2,
        reading: reading,
      );
      expect(rule.category, 'water');
      expect(rule.label, 'Elevated');
    });
  });
}
