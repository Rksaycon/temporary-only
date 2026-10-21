// Unit tests for the weather cache: round-trip serialization, staleness, and
// graceful handling of corrupt/absent data. Uses an in-memory KeyValueStore
// fake so no platform channel is needed.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:may_laud/features/rain_forecast/models/weather_data_models.dart';
import 'package:may_laud/features/rain_forecast/service/weather_cache.dart';
import 'package:may_laud/features/rain_forecast/types.dart';

/// In-memory [KeyValueStore] for tests.
class _FakeStore implements KeyValueStore {
  final Map<String, String> data = {};

  @override
  String? getString(String key) => data[key];

  @override
  Future<void> setString(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    data.remove(key);
  }
}

const _loc = Location(
  id: 'mld_milaor',
  name: 'Milaor',
  province: 'Camarines Sur',
  latitude: 13.7306,
  longitude: 123.4270,
);

WeatherForecastData _sample() => WeatherForecastData(
      location: _loc,
      sourceUrl: 'https://api.open-meteo.com/v1/forecast?x=1',
      callStartedAt: '2026-01-01T00:00:00.000',
      callFinishedAt: '2026-01-01T00:00:01.000',
      current: const CurrentWeather(
        time: '2026-01-01T12:00',
        temperatureC: 30.4,
        weatherCode: 3,
        precipitationMm: 0.2,
      ),
      daily: const [
        WeatherDay(
          time: '2026-01-01',
          temperatureMaxC: 31,
          temperatureMinC: 24,
          precipitationSumMm: 1.5,
          precipitationProbabilityMaxPct: 40,
          weatherCode: 3,
        ),
        WeatherDay(
          time: '2026-01-02',
          precipitationSumMm: 12.25,
          precipitationProbabilityMaxPct: 85,
        ),
      ],
      hourly: const [
        WeatherHour(
          time: '2026-01-01T00:00',
          precipitationMm: 0.1,
          precipitationProbabilityPct: 20,
        ),
      ],
      raw: const {'elevation': 5.0},
    );

void main() {
  late _FakeStore store;

  setUp(() {
    store = _FakeStore();
  });

  test('load returns null when nothing is cached', () async {
    final cache = WeatherCache(store: store);
    expect(await cache.load('mld_milaor'), isNull);
  });

  test('save then load round-trips the forecast', () async {
    final cache = WeatherCache(store: store);

    await cache.save(_sample());
    final cached = await cache.load('mld_milaor');

    expect(cached, isNotNull);
    final data = cached!.data;
    expect(data.location.id, 'mld_milaor');
    expect(data.dayCount, 2);
    expect(data.hourCount, 1);
    expect(data.current?.temperatureC, 30.4);
    expect(data.daily[1].precipitationSumMm, 12.25);
    expect(data.daily[1].precipitationProbabilityMaxPct, 85);
    expect(data.hourly.first.precipitationProbabilityPct, 20.0);
  });

  test('a freshly saved entry is not stale', () async {
    final cache = WeatherCache(store: store);
    await cache.save(_sample());
    final cached = await cache.load('mld_milaor');
    expect(cached!.isStaleAt(DateTime.now()), isFalse);
  });

  test('an old entry is considered stale', () async {
    // Seed a cache entry whose cachedAt is 12 hours in the past.
    final old = DateTime.now().subtract(const Duration(hours: 12));
    store.data['weather_cache_v1_mld_milaor'] = _encodeWithCachedAt(old);
    final cache = WeatherCache(store: store);
    final cached = await cache.load('mld_milaor');
    expect(cached, isNotNull);
    expect(cached!.isStaleAt(DateTime.now()), isTrue);
  });

  test('clear removes the entry', () async {
    final cache = WeatherCache(store: store);
    await cache.save(_sample());
    expect(await cache.load('mld_milaor'), isNotNull);
    await cache.clear('mld_milaor');
    expect(await cache.load('mld_milaor'), isNull);
  });

  test('corrupt JSON is handled gracefully (returns null)', () async {
    store.data['weather_cache_v1_mld_milaor'] = 'not-json{{{';
    final cache = WeatherCache(store: store);
    expect(await cache.load('mld_milaor'), isNull);
  });
}

/// Builds a minimal valid cache JSON with a specific cachedAt timestamp.
String _encodeWithCachedAt(DateTime cachedAt) {
  final sample = _sample();
  final map = <String, dynamic>{
    'location': {
      'id': sample.location.id,
      'name': sample.location.name,
      'province': sample.location.province,
      'latitude': sample.location.latitude,
      'longitude': sample.location.longitude,
    },
    'sourceUrl': sample.sourceUrl,
    'callStartedAt': sample.callStartedAt,
    'callFinishedAt': sample.callFinishedAt,
    'cachedAt': cachedAt.toIso8601String(),
    'current': null,
    'daily': [
      {'time': '2026-01-01', 'precipitation_sum': 1.5},
    ],
    'hourly': <dynamic>[],
    'raw': <String, dynamic>{},
  };
  return jsonEncode(map);
}
