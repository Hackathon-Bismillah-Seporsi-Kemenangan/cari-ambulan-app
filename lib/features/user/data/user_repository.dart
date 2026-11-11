import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_providers.dart';
import '../domain/emergency_history_item.dart';

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => ApiUserRepository(ref.watch(apiClientProvider)),
);

abstract class UserRepository {
  /// The patient's past requests, newest first.
  Future<List<EmergencyHistoryItem>> fetchHistory();

  /// Updates the account's name and phone (`PUT me`).
  Future<({String fullName, String? phone})> updateAccount({
    required String fullName,
    required String phone,
  });
}

class ApiUserRepository implements UserRepository {
  const ApiUserRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<EmergencyHistoryItem>> fetchHistory() async {
    final json = await _client.get('emergency-requests');
    return [
      for (final item in json?['data'] as List? ?? const [])
        EmergencyHistoryItem.fromJson(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<({String fullName, String? phone})> updateAccount({
    required String fullName,
    required String phone,
  }) async {
    final json = await _client.put('me', {
      'full_name': fullName,
      'phone': phone,
    });
    final data = json!['data'] as Map<String, dynamic>;
    return (
      fullName: (data['full_name'] ?? fullName) as String,
      phone: data['phone'] as String?,
    );
  }
}
