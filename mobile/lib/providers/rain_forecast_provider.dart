/// Riverpod state for the Rain Forecast / 7-day flood-risk screen.
///
/// This is the single source of truth the screen renders from. It wraps the
/// pure data layer (`WeatherRepository`, `WeatherCache`, `WaterLevelSource`)
/// and exposes an explicit status so the UI never has to guess whether a value
/// is loading, stale, offline, or genuinely unavailable.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/rain_forecast/models/weather_data_models.dart';
import '../features/rain_forecast/repository/weather_repository.dart';
import '../features/rain_forecast/service/water_level_source.dart';
import '../features/rain_forecast/service/weather_cache.dart';
import '../features/rain_forecast/types.dart';

/// Lifecycle of a forecast load.
enum RainForecastStatus {
  /// First load, nothing to show yet.
  initial,

  /// First load in progress (may still be showing cache underneath).
  loading,

  /// A manual/auto refresh is in progress while data is already visible.
  refreshing,

  /// Fresh data is available.
  loaded,

  /// No network and no usable cache.
  offline,

  /// The request failed for a non-network reason (server/parse/timeout).
  error,
}

/// Immutable UI state.
class RainForecastState {
  final RainForecastStatus status;
  final Location location;

  /// The forecast data (from cache or network). Null before first success.
  final WeatherForecastData? data;

  /// When [data] was produced (cache time or network finish time).
  final DateTime? lastUpdated;

  /// True when [data] came from cache and is older than [kWeatherStaleAfter].
  final bool isStale;

  /// True when the last attempt could not reach the network.
  final bool isOffline;

  /// Human-readable error message for the error/offline states.
  final String? message;

  /// River water-level information (measured/forecast/advisory), or an honest
  /// "unavailable" snapshot. Never fabricated.
  final WaterLevelSnapshot waterLevel;

  const RainForecastState({
    required this.status,
    required this.location,
    this.data,
    this.lastUpdated,
    this.isStale = false,
    this.isOffline = false,
    this.message,
    this.waterLevel = const WaterLevelSnapshot(
      availability: WaterLevelAvailability.unavailable,
      message: 'Checking river water-level availability…',
    ),
  });

  bool get hasData => data != null;
  bool get isLoading =>
      status == RainForecastStatus.initial ||
      status == RainForecastStatus.loading;
  bool get isRefreshing => status == RainForecastStatus.refreshing;

  RainForecastState copyWith({
    RainForecastStatus? status,
    WeatherForecastData? data,
    DateTime? lastUpdated,
    bool? isStale,
    bool? isOffline,
    String? message,
    WaterLevelSnapshot? waterLevel,
    bool clearMessage = false,
  }) {
    return RainForecastState(
      status: status ?? this.status,
      location: location,
      data: data ?? this.data,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isStale: isStale ?? this.isStale,
      isOffline: isOffline ?? this.isOffline,
      message: clearMessage ? null : (message ?? this.message),
      waterLevel: waterLevel ?? this.waterLevel,
    );
  }
}

/// Controller that loads the forecast cache-first, then refreshes.
class RainForecastController extends StateNotifier<RainForecastState> {
  final WeatherRepository _repository;
  final WeatherCache _cache;
  final WaterLevelSource _waterLevelSource;
  final Connectivity _connectivity;
  final Location _location;

  RainForecastController({
    required Location location,
    WeatherRepository? repository,
    WeatherCache? cache,
    WaterLevelSource? waterLevelSource,
    Connectivity? connectivity,
  })  : _repository = repository ?? const WeatherRepository(),
        _cache = cache ?? WeatherCache(),
        _waterLevelSource =
            waterLevelSource ?? const UnavailableWaterLevelSource(),
        _connectivity = connectivity ?? Connectivity(),
        _location = location,
        super(RainForecastState(
          status: RainForecastStatus.initial,
          location: location,
        )) {
    // Kick off the first load.
    unawaited(load());
  }

  /// Whether the device currently has any network connection.
  Future<bool> _isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (_) {
      // If we cannot determine connectivity, assume online and let the
      // network call itself surface any real failure.
      return true;
    }
  }

  /// Loads cache immediately (instant, possibly stale), then refreshes from
  /// the network. Safe to call repeatedly (e.g. pull-to-refresh).
  Future<void> load({bool forceRefresh = false}) async {
    final alreadyHaveData = state.hasData;

    if (!alreadyHaveData || forceRefresh) {
      state = state.copyWith(
        status: alreadyHaveData
            ? RainForecastStatus.refreshing
            : RainForecastStatus.loading,
        clearMessage: true,
      );
    }

    // 1) Show cache instantly (unless a refresh already provided fresh data).
    if (!alreadyHaveData) {
      final cached = await _cache.load(_location.id);
      if (cached != null) {
        final stale = cached.isStaleAt(DateTime.now());
        state = state.copyWith(
          status: RainForecastStatus.loaded,
          data: cached.data,
          lastUpdated: cached.cachedAt,
          isStale: stale,
          isOffline: false,
          clearMessage: true,
        );
      }
    }

    // 2) Connectivity gate — surface an honest offline state.
    final online = await _isOnline();
    if (!online) {
      if (state.hasData) {
        state = state.copyWith(
          status: RainForecastStatus.loaded,
          isOffline: true,
          isStale: true,
          message: 'You are offline. Showing the last saved forecast.',
        );
      } else {
        state = state.copyWith(
          status: RainForecastStatus.offline,
          isOffline: true,
          message:
              'No internet connection and no saved forecast is available yet.',
        );
      }
      await _loadWaterLevel();
      return;
    }

    // 3) Network fetch.
    try {
      final data = await _repository.fetchForecast(_location);
      if (data == null) {
        // Repository returns null for unavailable/invalid — keep any cache.
        if (state.hasData) {
          state = state.copyWith(
            status: RainForecastStatus.loaded,
            isStale: true,
            message:
                'Could not refresh right now. Showing the last saved forecast.',
          );
        } else {
          state = state.copyWith(
            status: RainForecastStatus.error,
            message:
                'Unable to load the forecast right now. Please check your connection and try again.',
          );
        }
      } else {
        final finished =
            DateTime.tryParse(data.callFinishedAt) ?? DateTime.now();
        await _cache.save(data);
        state = state.copyWith(
          status: RainForecastStatus.loaded,
          data: data,
          lastUpdated: finished,
          isStale: false,
          isOffline: false,
          clearMessage: true,
        );
      }
    } catch (_) {
      if (state.hasData) {
        state = state.copyWith(
          status: RainForecastStatus.loaded,
          isStale: true,
          message:
              'Could not refresh right now. Showing the last saved forecast.',
        );
      } else {
        state = state.copyWith(
          status: RainForecastStatus.error,
          message:
              'Something went wrong loading the forecast. Please try again.',
        );
      }
    }

    await _loadWaterLevel();
  }

  /// Pull-to-refresh entry point.
  Future<void> refresh() => load(forceRefresh: true);

  Future<void> _loadWaterLevel() async {
    try {
      final snapshot = await _waterLevelSource.fetch(_location);
      state = state.copyWith(waterLevel: snapshot);
    } catch (_) {
      state = state.copyWith(
        waterLevel: const WaterLevelSnapshot(
          availability: WaterLevelAvailability.unavailable,
          message: 'River water-level forecast unavailable for this location.',
        ),
      );
    }
  }
}

// ── Providers ────────────────────────────────────────────────────────────

/// Repository singleton (pure, const-constructible).
final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return const WeatherRepository();
});

/// Cache singleton.
final weatherCacheProvider = Provider<WeatherCache>((ref) {
  return WeatherCache();
});

/// The water-level source. Swap [UnavailableWaterLevelSource] for a verified
/// provider here when one becomes available (see docs/RAIN_FORECAST_FEATURE.md).
final waterLevelSourceProvider = Provider<WaterLevelSource>((ref) {
  return const UnavailableWaterLevelSource();
});

/// Auto-disposing forecast controller for the assigned Milaor location.
final rainForecastProvider = StateNotifierProvider.autoDispose<
    RainForecastController, RainForecastState>(
  (ref) {
    return RainForecastController(
      location: assignedLocation,
      repository: ref.watch(weatherRepositoryProvider),
      cache: ref.watch(weatherCacheProvider),
      waterLevelSource: ref.watch(waterLevelSourceProvider),
    );
  },
);
