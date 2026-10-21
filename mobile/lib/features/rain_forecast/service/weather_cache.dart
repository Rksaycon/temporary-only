/// Best-effort local cache for the last successful weather snapshot.
///
/// Goals:
///  - open instantly from cache on launch, then refresh from the network,
///  - show a stale-data indicator with the original update time,
///  - never cache a fabricated value — only real API payloads reach here.
///
/// Backed by SharedPreferences (small JSON strings). All operations swallow
/// errors: caching is an optimization, never a hard dependency.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_data_models.dart';
import '../types.dart';

/// Age after which a cached snapshot is considered stale and should be
/// refreshed (Open-Meteo daily forecasts update roughly a few times a day).
const Duration kWeatherStaleAfter = Duration(hours: 6);

/// A cached forecast together with the moment it was stored.
@immutable
class CachedForecast {
  final WeatherForecastData data;
  final DateTime cachedAt;

  const CachedForecast({required this.data, required this.cachedAt});

  bool isStaleAt(DateTime now) => now.difference(cachedAt) > kWeatherStaleAfter;
}

/// Minimal string key/value store abstraction so the cache can be unit-tested
/// without a platform channel (SharedPreferences' mock store moved between
/// versions). [SharedPrefsStore] is the production implementation.
abstract class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

/// SharedPreferences-backed [KeyValueStore].
class SharedPrefsStore implements KeyValueStore {
  final SharedPreferences _prefs;
  SharedPrefsStore(this._prefs);

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// Simple weather cache keyed by location id, backed by a [KeyValueStore].
class WeatherCache {
  /// Optionally injected store (used by tests). When null, a SharedPreferences
  /// store is created lazily on first use.
  final KeyValueStore? _store;

  WeatherCache({KeyValueStore? store}) : _store = store;

  static const String _prefix = 'weather_cache_v1_';

  String _key(String locationId) => '$_prefix$locationId';

  Future<KeyValueStore> get _storeFuture async =>
      _store ?? SharedPrefsStore(await SharedPreferences.getInstance());

  /// Persists [data] for its location. Best-effort; failures are ignored.
  Future<void> save(WeatherForecastData data) async {
    try {
      final store = await _storeFuture;
      final loc = data.location;
      final map = <String, dynamic>{
        'location': <String, dynamic>{
          'id': loc.id,
          'name': loc.name,
          'province': loc.province,
          'latitude': loc.latitude,
          'longitude': loc.longitude,
          'officialName': loc.officialName,
        },
        'sourceUrl': data.sourceUrl,
        'callStartedAt': data.callStartedAt,
        'callFinishedAt': data.callFinishedAt,
        'cachedAt': DateTime.now().toIso8601String(),
        'current': _currentToJson(data.current),
        'daily': data.daily.map(_dayToJson).toList(),
        'hourly': data.hourly.map(_hourToJson).toList(),
        'raw': data.raw,
      };
      await store.setString(_key(loc.id), jsonEncode(map));
    } catch (_) {
      // Caching is best-effort — ignore serialization/storage errors.
    }
  }

  /// Loads the cached forecast for [locationId], or null when none/invalid.
  Future<CachedForecast?> load(String locationId) async {
    try {
      final store = await _storeFuture;
      final raw = store.getString(_key(locationId));
      if (raw == null) return null;
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      final data = _fromJson(map);
      if (data == null) return null;
      final cachedAt = DateTime.tryParse(map['cachedAt']?.toString() ?? '') ??
          DateTime.now();
      return CachedForecast(data: data, cachedAt: cachedAt);
    } catch (_) {
      return null;
    }
  }

  /// Removes the cached forecast for [locationId].
  Future<void> clear(String locationId) async {
    try {
      final store = await _storeFuture;
      await store.remove(_key(locationId));
    } catch (_) {
      // ignore
    }
  }

  // ── JSON (de)serialization ────────────────────────────────────────────

  WeatherForecastData? _fromJson(Map<String, dynamic> map) {
    final locMap = map['location'];
    if (locMap is! Map) return null;
    final loc = Location(
      id: locMap['id']?.toString() ?? '',
      name: locMap['name']?.toString() ?? '',
      province: locMap['province']?.toString() ?? '',
      latitude: (locMap['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (locMap['longitude'] as num?)?.toDouble() ?? 0,
      officialName: locMap['officialName'] as String?,
    );
    final currentMap = map['current'];
    final daily = ((map['daily'] as List?) ?? const [])
        .whereType<Map>()
        .map(_dayFromJson)
        .toList();
    final hourly = ((map['hourly'] as List?) ?? const [])
        .whereType<Map>()
        .map(_hourFromJson)
        .toList();
    final rawMap =
        (map['raw'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return WeatherForecastData(
      location: loc,
      sourceUrl: map['sourceUrl']?.toString() ?? '',
      callStartedAt: map['callStartedAt']?.toString() ?? '',
      callFinishedAt: map['callFinishedAt']?.toString() ?? '',
      current: currentMap is Map
          ? _currentFromJson(currentMap.cast<String, dynamic>())
          : null,
      daily: daily,
      hourly: hourly,
      raw: rawMap,
    );
  }

  static Map<String, dynamic> _dayToJson(WeatherDay d) => <String, dynamic>{
        'time': d.time,
        'temperatureMaxC': d.temperatureMaxC,
        'temperatureMinC': d.temperatureMinC,
        'precipitationSumMm': d.precipitationSumMm,
        'rainSumMm': d.rainSumMm,
        'showersSumMm': d.showersSumMm,
        'precipitationProbabilityMaxPct': d.precipitationProbabilityMaxPct,
        'weatherCode': d.weatherCode,
        'windSpeedMaxKmh': d.windSpeedMaxKmh,
      };

  static WeatherDay _dayFromJson(Map m) => WeatherDay(
        time: m['time']?.toString() ?? '',
        temperatureMaxC: (m['temperatureMaxC'] as num?)?.round(),
        temperatureMinC: (m['temperatureMinC'] as num?)?.round(),
        precipitationSumMm: (m['precipitationSumMm'] as num?)?.toDouble(),
        rainSumMm: (m['rainSumMm'] as num?)?.toDouble(),
        showersSumMm: (m['showersSumMm'] as num?)?.toDouble(),
        precipitationProbabilityMaxPct:
            (m['precipitationProbabilityMaxPct'] as num?)?.round(),
        weatherCode: (m['weatherCode'] as num?)?.round(),
        windSpeedMaxKmh: m['windSpeedMaxKmh']?.toString(),
      );

  static Map<String, dynamic> _hourToJson(WeatherHour h) => <String, dynamic>{
        'time': h.time,
        'precipitationMm': h.precipitationMm,
        'rainMm': h.rainMm,
        'showersMm': h.showersMm,
        'precipitationProbabilityPct': h.precipitationProbabilityPct,
        'weatherCode': h.weatherCode,
        'windSpeedKmh': h.windSpeedKmh,
      };

  static WeatherHour _hourFromJson(Map m) => WeatherHour(
        time: m['time']?.toString() ?? '',
        precipitationMm: (m['precipitationMm'] as num?)?.toDouble(),
        rainMm: (m['rainMm'] as num?)?.toDouble(),
        showersMm: (m['showersMm'] as num?)?.toDouble(),
        precipitationProbabilityPct:
            (m['precipitationProbabilityPct'] as num?)?.toDouble(),
        weatherCode: (m['weatherCode'] as num?)?.round(),
        windSpeedKmh: (m['windSpeedKmh'] as num?)?.toDouble(),
      );

  static Map<String, dynamic>? _currentToJson(CurrentWeather? c) {
    if (c == null) return null;
    return <String, dynamic>{
      'time': c.time,
      'temperatureC': c.temperatureC,
      'weatherCode': c.weatherCode,
      'windSpeedKmh': c.windSpeedKmh,
      'precipitationMm': c.precipitationMm,
      'relativeHumidityPct': c.relativeHumidityPct,
    };
  }

  static CurrentWeather? _currentFromJson(Map<String, dynamic> m) =>
      CurrentWeather(
        time: m['time'] as String?,
        temperatureC: (m['temperatureC'] as num?)?.toDouble(),
        weatherCode: (m['weatherCode'] as num?)?.round(),
        windSpeedKmh: (m['windSpeedKmh'] as num?)?.toDouble(),
        precipitationMm: (m['precipitationMm'] as num?)?.toDouble(),
        relativeHumidityPct: (m['relativeHumidityPct'] as num?)?.toDouble(),
      );
}
