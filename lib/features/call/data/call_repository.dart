import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_providers.dart';
import '../domain/call_models.dart';

final callRepositoryProvider = Provider<CallRepository>(
  (ref) => ApiCallRepository(ref.watch(apiClientProvider)),
);

/// Voice calls between the patient and the driver of an active trip.
abstract class CallRepository {
  /// Rings the other side of [requestId]. Throws [CallAlreadyRinging] when
  /// the other side is calling at the same moment.
  Future<TripCall> start(String requestId);

  /// The call ringing for this user, if any.
  Future<TripCall?> incoming();

  Future<TripCall> status(String callId);

  /// The LiveKit room to join for [callId].
  Future<CallConnection> connection(String callId);

  Future<void> answer(String callId);
  Future<void> decline(String callId);
  Future<void> end(String callId);
}

/// Both sides pressed "Telepon" together: answer [callId] instead.
class CallAlreadyRinging implements Exception {
  const CallAlreadyRinging(this.callId);

  final String callId;
}

class ApiCallRepository implements CallRepository {
  const ApiCallRepository(this._client);

  final ApiClient _client;

  @override
  Future<TripCall> start(String requestId) async {
    try {
      final json = await _client.post('emergency-requests/$requestId/calls');
      return TripCall.fromJson(json!['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      final ringing = e.body?['incoming_call_id'] as String?;
      if (e.isConflict && ringing != null) throw CallAlreadyRinging(ringing);
      rethrow;
    }
  }

  @override
  Future<TripCall?> incoming() async {
    final json = await _client.get('calls/incoming');
    final data = json?['data'] as Map<String, dynamic>?;
    return data == null ? null : TripCall.fromJson(data);
  }

  @override
  Future<TripCall> status(String callId) async {
    final json = await _client.get('calls/$callId');
    return TripCall.fromJson(json!['data'] as Map<String, dynamic>);
  }

  @override
  Future<CallConnection> connection(String callId) async {
    final json = await _client.get('calls/$callId/token');
    final url = json?['url'] as String? ?? json?['server_url'] as String?;
    final token = json?['token'] as String?;
    if (url == null || token == null) {
      throw const ApiException('Server panggilan belum siap.');
    }
    return (url: url, token: token);
  }

  @override
  Future<void> answer(String callId) => _client.post('calls/$callId/answer');

  @override
  Future<void> decline(String callId) => _client.post('calls/$callId/decline');

  @override
  Future<void> end(String callId) => _client.post('calls/$callId/end');
}
