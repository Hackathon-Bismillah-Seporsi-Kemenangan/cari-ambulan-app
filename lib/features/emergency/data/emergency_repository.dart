import '../domain/emergency_models.dart';

abstract class EmergencyRepository {
  /// Create a new emergency request (SOS).
  Future<EmergencyRequestModel> createEmergencyRequest({
    required double latitude,
    required double longitude,
    required String address,
    bool isForSelf = true,
    String? emergencyType,
    String? severityLevel,
    String? notes,
  });

  /// Get active ongoing emergency request for current user.
  Future<EmergencyRequestModel?> getCurrentRequest();

  /// Cancel an active emergency request.
  Future<EmergencyRequestModel> cancelRequest(String id, {String? reason});

  /// The request with its search progress or ambulance, polled while open.
  Future<EmergencyRequestModel> getRequest(String id);

  /// Widens the search to the next radius step and rings the next drivers.
  Future<EmergencyRequestModel> widenRadius(String id);

  /// "Cari Lagi": searches the full radius again, including drivers who
  /// declined.
  Future<EmergencyRequestModel> retrySearch(String id);
}
