import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_providers.dart';
import '../domain/medical_profile.dart';

final medicalRepositoryProvider = Provider<MedicalRepository>(
  (ref) => ApiMedicalRepository(ref.watch(apiClientProvider)),
);

abstract class MedicalRepository {
  /// The user's Medical ID; [MedicalProfile.empty] before it is filled in.
  Future<MedicalProfile> fetch();

  /// Creates or replaces the Medical ID.
  Future<MedicalProfile> save(MedicalProfile profile);
}

class ApiMedicalRepository implements MedicalRepository {
  const ApiMedicalRepository(this._client);

  final ApiClient _client;

  @override
  Future<MedicalProfile> fetch() async {
    final json = await _client.get('me/medical-profile');
    final data = json?['data'] as Map<String, dynamic>?;
    return data == null ? MedicalProfile.empty : MedicalProfile.fromJson(data);
  }

  @override
  Future<MedicalProfile> save(MedicalProfile profile) async {
    final json = await _client.put('me/medical-profile', profile.toJson());
    final data = json?['data'] as Map<String, dynamic>?;
    return data == null ? profile : MedicalProfile.fromJson(data);
  }
}
