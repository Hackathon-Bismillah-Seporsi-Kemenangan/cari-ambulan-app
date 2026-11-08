import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_providers.dart';
import '../domain/emergency_models.dart';
import 'emergency_repository.dart';

final emergencyRepositoryProvider = Provider<EmergencyRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiEmergencyRepository(apiClient);
});

class ApiEmergencyRepository implements EmergencyRepository {
  const ApiEmergencyRepository(this._client);

  final ApiClient _client;

  @override
  Future<EmergencyRequestModel> createEmergencyRequest({
    required double latitude,
    required double longitude,
    required String address,
    bool isForSelf = true,
    String? emergencyType,
    String? severityLevel,
    String? notes,
  }) async {
    final response = await _client.post('emergency-requests', {
      'is_for_self': isForSelf,
      'emergency_type': emergencyType ?? 'Darurat Umum',
      'severity_level': severityLevel ?? 'critical',
      'patient_notes': notes,
      'pickup_latitude': latitude,
      'pickup_longitude': longitude,
      'pickup_address': address,
    });

    final data = response?['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw const ApiException('Respons server tidak valid');
    }

    return EmergencyRequestModel.fromJson(data);
  }

  @override
  Future<EmergencyRequestModel?> getCurrentRequest() async {
    final response = await _client.get('emergency-requests/current');
    final data = response?['data'] as Map<String, dynamic>?;
    if (data == null) return null;

    return EmergencyRequestModel.fromJson(data);
  }

  @override
  Future<EmergencyRequestModel> cancelRequest(String id, {String? reason}) async {
    final response = await _client.post('emergency-requests/$id/cancel', {
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });

    final data = response?['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw const ApiException('Gagal membatalkan panggilan darurat');
    }

    return EmergencyRequestModel.fromJson(data);
  }
}

