import '../../../core/network/api_client.dart';
import '../domain/driver_models.dart';
import 'driver_repository.dart';

class ApiDriverRepository implements DriverRepository {
  ApiDriverRepository(this._client);

  final ApiClient _client;

  @override
  Future<DriverProfile> fetchProfile() async {
    final json = await _client.get('driver/profile');
    final data = json!['data'] as Map<String, dynamic>;
    return DriverProfile.fromJson(data);
  }

  @override
  Future<DriverProfile> setAvailability(
    DriverAvailability availability, {
    double? latitude,
    double? longitude,
  }) async {
    final payload = <String, dynamic>{
      'status': availability.name,
    };
    if (latitude != null) {
      payload['latitude'] = latitude;
    }
    if (longitude != null) {
      payload['longitude'] = longitude;
    }

    final json = await _client.put('driver/availability', payload);
    final data = json!['data'] as Map<String, dynamic>;
    return DriverProfile.fromJson(data);
  }

  @override
  Future<void> sendLocation(double latitude, double longitude) async {
    await _client.post('driver/location', {
      'latitude': latitude,
      'longitude': longitude,
    });
  }
}
