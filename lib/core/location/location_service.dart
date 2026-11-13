import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../permissions/permission_requests.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// The phone's position while a screen listens, e.g. the trip navigation.
final liveLocationProvider = StreamProvider.autoDispose<LatLng>((ref) {
  return ref.watch(locationServiceProvider).watch();
});

class LocationService {
  /// Where maps open without a fix (Monas, Jakarta). Never sent as a position.
  static const defaultLatitude = -6.2088;
  static const defaultLongitude = 106.8222;

  Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] GPS is turned off, using fallback.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await PermissionRequests.run(Geolocator.requestPermission);
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Location permission denied.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Location permission permanently denied.');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint('[LocationService] Error getting location: $e');
      return null;
    }
  }

  /// Current position first, then every ~5 m of movement. Falls back to the
  /// default position once when GPS is off or denied.
  Stream<LatLng> watch() async* {
    final first = await getCurrentPosition();
    if (first == null) {
      yield const LatLng(defaultLatitude, defaultLongitude);
      return;
    }
    yield LatLng(first.latitude, first.longitude);

    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        // Small enough that the ambulance moves smoothly on the map.
        distanceFilter: 5,
      ),
    ).map((pos) => LatLng(pos.latitude, pos.longitude));
  }

  /// A real position to send an ambulance to: a fresh fix, else the last
  /// one the phone knows. Null when location is off or denied: never the
  /// default, which would send the ambulance to the wrong place.
  Future<({double latitude, double longitude})?> emergencyFix() async {
    final pos = await getCurrentPosition() ?? await _lastKnown();
    if (pos == null) return null;
    return (latitude: pos.latitude, longitude: pos.longitude);
  }

  Future<Position?> _lastKnown() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      debugPrint('[LocationService] No last known position: $e');
      return null;
    }
  }

  /// The street at a point from the phone's own geocoder (free, no API key),
  /// e.g. "Jl. Kenanga No. 5". Falls back to the coordinates, so the driver
  /// still has the exact point when the geocoder is offline or slow.
  Future<String> addressOf(double latitude, double longitude) async {
    try {
      final places = await Geocoding(locale: const Locale('id', 'ID'))
          .placemarkFromCoordinates(latitude, longitude)
          .timeout(const Duration(seconds: 4));
      if (places.isNotEmpty) {
        final address = formatPlacemark(places.first);
        if (address != null) return address;
      }
    } catch (e) {
      debugPrint('[LocationService] Reverse geocoding failed: $e');
    }
    return coordinatesLabel(latitude, longitude);
  }

  static String coordinatesLabel(double latitude, double longitude) =>
      'Titik GPS ${latitude.toStringAsFixed(5)}, '
      '${longitude.toStringAsFixed(5)}';

  /// Street and number, then the area, e.g. "Jl. Kenanga No. 5, Menteng".
  static String? formatPlacemark(Placemark place) {
    bool filled(String? s) => s != null && s.trim().isNotEmpty;

    String? street;
    final road = place.thoroughfare;
    if (filled(road)) {
      final number = place.subThoroughfare;
      street = !filled(number)
          ? road
          // Some geocoders already write "No.39".
          : number!.toLowerCase().startsWith('no')
          ? '$road $number'
          : '$road No. $number';
    } else if (filled(place.street) && !place.street!.contains('+')) {
      // Without a road, "street" may be a plus code like "6RQ8+2X".
      street = place.street;
    }
    final area = [
      place.subLocality,
      place.locality,
    ].firstWhere(filled, orElse: () => null);
    final parts = [?street, if (area != street) ?area];
    return parts.isEmpty ? null : parts.join(', ');
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
      debugPrint('[LocationService] Could not open settings: $e');
    }
  }
}
