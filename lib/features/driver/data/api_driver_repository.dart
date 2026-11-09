import '../../../core/network/api_client.dart';
import '../../emergency/domain/emergency_models.dart';
import '../domain/dispatch_offer_model.dart';
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

  @override
  Future<DispatchOfferModel?> getCurrentOffer() async {
    final response = await _client.get('driver/offers/current');
    final data = response?['data'] as Map<String, dynamic>?;
    if (data == null) return null;
    return DispatchOfferModel.fromJson(data);
  }

  @override
  Future<EmergencyRequestModel> acceptRequest(String requestId) =>
      _tripAction(requestId, 'accept', 'Gagal menerima panggilan');

  @override
  Future<void> declineRequest(String requestId) async {
    await _client.post('driver/requests/$requestId/decline');
  }

  @override
  Future<EmergencyRequestModel?> getActiveTrip() async {
    final response = await _client.get('driver/trip');
    final data = response?['data'] as Map<String, dynamic>?;
    if (data == null) return null;
    return EmergencyRequestModel.fromJson(data);
  }

  @override
  Future<EmergencyRequestModel> markArrived(String requestId) =>
      _tripAction(requestId, 'arrive', 'Gagal memperbarui status perjalanan');

  @override
  Future<EmergencyRequestModel> startToHospital(String requestId) =>
      _tripAction(requestId, 'start-to-hospital', 'Gagal memperbarui status perjalanan');

  @override
  Future<EmergencyRequestModel> completeTrip(String requestId) =>
      _tripAction(requestId, 'complete', 'Gagal menyelesaikan perjalanan');

  Future<EmergencyRequestModel> _tripAction(
    String requestId,
    String action,
    String failure,
  ) async {
    final response = await _client.post('driver/requests/$requestId/$action');
    final data = response?['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw ApiException(failure);
    }
    return EmergencyRequestModel.fromJson(data);
  }
}
