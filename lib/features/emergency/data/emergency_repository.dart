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
}

