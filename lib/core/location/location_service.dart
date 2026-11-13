import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_log.dart';
import '../permissions/permission_requests.dart';

/// A GPS reading. [accuracyMeters] is null for the fallback position.
typedef LocationFix = ({LatLng point, double? accuracyMeters});

/// The phone's GPS position, asking for permission when needed.
class LocationService {
  /// Used when location is off or denied, so the app still opens (Jember,
  /// inside the offline map's East Java). Dispatch will be wrong until GPS
  /// is enabled.
  static const fallback = LatLng(-8.1724, 113.7008);

  static const _savedKey = 'last_location';

  static const _settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    // Small enough that an ambulance on a map moves smoothly, not in jumps.
    distanceFilter: 5,
  );

  /// Current position first, then every ~5 m of movement.
  Stream<LatLng> watch() => watchFix().map((fix) => fix.point);

  /// Like [watch], with the reported accuracy.
  Stream<LocationFix> watchFix() async* {
    const fallbackFix = (point: fallback, accuracyMeters: null);
    if (!await _ensurePermission()) {
      yield fallbackFix;
      return;
    }

    final last = await Geolocator.getLastKnownPosition();
    if (last != null) yield _toFix(last);

    try {
      yield _saved(
        await Geolocator.getCurrentPosition(
          locationSettings: _settings,
        ).timeout(const Duration(seconds: 10)),
      );
    } on TimeoutException {
      if (last == null) yield fallbackFix;
    }

    yield* Geolocator.getPositionStream(
      locationSettings: _settings,
    ).map(_saved);
  }

  /// A real position for sending an emergency, asking for permission again
  /// when needed. Null when location is off, denied or GPS doesn't answer:
  /// never the [fallback], which would send the ambulance to the wrong city.
  Future<LocationFix?> currentFix() async {
    if (!await _ensurePermission()) return null;
    try {
      return _saved(
        await Geolocator.getCurrentPosition(
          locationSettings: _settings,
        ).timeout(const Duration(seconds: 15)),
      );
    } catch (e) {
      AppLog.warn('Lokasi', 'No GPS fix for the emergency', e);
      final last = await Geolocator.getLastKnownPosition().catchError(
        (Object _) => null,
      );
      return last == null ? null : _toFix(last);
    }
  }

  /// Where the user can turn location back on: the phone's location switch
  /// when it's off, otherwise this app's permissions.
  Future<void> openSettings() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    } catch (e) {
      AppLog.warn('Lokasi', 'Could not open settings', e);
    }
  }

  /// Where the phone was at the last GPS fix, from an earlier run, so a map
  /// can open there before GPS answers. Null on a first run.
  Future<LatLng?> lastSaved() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getStringList(
        _savedKey,
      );
      if (saved == null) return null;
      return LatLng(double.parse(saved[0]), double.parse(saved[1]));
    } catch (e) {
      AppLog.warn('Lokasi', 'Saved location unreadable', e);
      return null;
    }
  }

  /// [_toFix], remembering the position for [lastSaved].
  LocationFix _saved(Position p) {
    SharedPreferences.getInstance()
        .then(
          (prefs) => prefs.setStringList(_savedKey, [
            '${p.latitude}',
            '${p.longitude}',
          ]),
        )
        .ignore();
    return _toFix(p);
  }

  Future<bool> _ensurePermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await PermissionRequests.run(Geolocator.requestPermission);
      }
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      AppLog.warn('Lokasi', 'Location unavailable', e);
      return false;
    }
  }

  LocationFix _toFix(Position p) =>
      (point: LatLng(p.latitude, p.longitude), accuracyMeters: p.accuracy);
}
