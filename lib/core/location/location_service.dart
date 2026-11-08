import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

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

  Future<({double latitude, double longitude})> getCoordinates() async {
    final pos = await getCurrentPosition();
    if (pos != null) {
      return (latitude: pos.latitude, longitude: pos.longitude);
    }
    return (latitude: defaultLatitude, longitude: defaultLongitude);
  }
}

