import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// The phone's position while a screen listens, e.g. the trip navigation.
final liveLocationProvider = StreamProvider.autoDispose<LatLng>((ref) {
  return ref.watch(locationServiceProvider).watch();
});

class LocationService {
  // Default fallback (Jakarta Pusat / Monas area)
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
        permission = await Geolocator.requestPermission();
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

  Future<({double latitude, double longitude})> getCoordinates() async {
    final pos = await getCurrentPosition();
    if (pos != null) {
      return (latitude: pos.latitude, longitude: pos.longitude);
    }
    return (latitude: defaultLatitude, longitude: defaultLongitude);
  }

  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    // In demo / hackathon mode, return readable approximate address
    return 'Jl. Medan Merdeka Barat No. 17, Jakarta Pusat ($latitude, $longitude)';
  }
}
