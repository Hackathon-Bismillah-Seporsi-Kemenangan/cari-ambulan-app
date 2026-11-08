import '../domain/driver_models.dart';

abstract class DriverRepository {
  Future<DriverProfile> fetchProfile();

  Future<DriverProfile> setAvailability(
    DriverAvailability availability, {
    double? latitude,
    double? longitude,
  });
}

