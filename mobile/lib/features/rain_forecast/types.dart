/// Location registry for May-Laud participatory forecast features.
library;

///
/// Coordinates were taken from the official Philippine Geodesy and Hydrostic
/// Office (PGH) / PAGASA gazetteer for Milaor, Camarines Sur.
/// Value objects are shared between the UI layer and the data layers so no
/// screen, provider, or repository invents its own coordinates.
import 'package:flutter/foundation.dart';

/// A geo-tagged location understood by the local forecast stack.
@immutable
class Location {
  final String id;
  final String name;
  final String province;
  final double latitude;
  final double longitude;
  final String? officialName;

  const Location({
    required this.id,
    required this.name,
    required this.province,
    required this.latitude,
    required this.longitude,
    this.officialName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Location && id == other.id;

  @override
  int get hashCode => Object.hash(id, latitude, longitude);

  /// Approximate radius in kilometres for the grid-cell area estimate.
  ///
  /// A single barangay is normally under 10 km across. The Open-Meteo API
  /// returns area-level (grid-cell) values here, so we attach this radius to
  /// make the "grid-cell estimate" disclaimer self-documenting.
  static const double gridCellKm = 9.0;

  String get displayName => officialName ?? name;

  @override
  String toString() => 'Location($name, $latitude, $longitude)';
}

/// Canonical location pre-selected by the app for May-Laud residents.
///
/// May-Laud currently assigns every citizen to Milaor, Camarines Sur. The
/// app does not yet maintain a per-citizen barangay coordinate table, so the
/// assignment is a single-map constant that can be swapped out once a
/// verified coordinate table exists (see [LocationConfig]).
const Location assignedLocation = Location(
  id: 'mld_milaor',
  name: 'Milaor',
  province: 'Camarines Sur',
  latitude: 13.7306,
  longitude: 123.4270,
  officialName: 'Milaor, Camarines Sur',
);

/// Validated geographic registry. Do not add coordinates here unless they are
/// traceable to an official gazetteer (PGH/PAGASA). Missing entries must
/// remain absent, never guessed.
class LocationConfig {
  static final List<Location> _registry = [
    assignedLocation,
  ];

  const LocationConfig._();

  static List<Location> all() => List.unmodifiable(_registry);

  static Location? findBy(String id) =>
      _registry.firstWhere((l) => l.id == id, orElse: () => assignedLocation);

  /// True when the app has a verified coordinate for [location].
  static bool hasCoordinate(String locationId) => findBy(locationId) != null;

  /// Coordinates are NOT guaranteed to be inside the barangay. Open-Meteo
  /// consumes a grid cell whose footprint can cover several barangays, so
  /// weather values are area estimates unless a station-level reading is
  /// separately supplied by an official source.
  static bool isAreaEstimate(String locationId) => true;

  /// No barangay-specific weather station exists yet in the app's verified
  /// registry. Add one with a documented coordinate only after confirming it
  /// against the official gazetteer.
  static bool hasBarangayWeatherStation(String locationId) => false;

  /// Returns a disclosure string describing the granularity of the supplied
  /// coordinates for the given location id. The UI renders this next to every
  /// weather value so a rainfall number is never mistaken for a
  /// station measurement.
  static String locationDetailDescription(String locationId) {
    final loc = findBy(locationId) ?? assignedLocation;
    if (!hasCoordinate(locationId)) {
      return 'No verified coordinates available for ${loc.name}. Use area-level estimates only.';
    }
    if (hasBarangayWeatherStation(locationId)) {
      return '${loc.name} - verified local weather station.';
    }
    return '${loc.displayName} - grid-cell area estimate. Values are interpolated for the surrounding area and are not measurements taken inside the barangay.';
  }
}
