import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_log.dart';
import '../network/api_client.dart';
import '../network/api_providers.dart';
import 'push_service.dart';

final pushRegistrationProvider = Provider<PushRegistration>((ref) {
  final registration = PushRegistration(
    ref.watch(apiClientProvider),
    token: PushService.token,
    tokenRefreshes: PushService.tokenRefreshes,
    deviceType: PushService.deviceType,
  );
  ref.onDispose(registration.dispose);
  return registration;
});

/// Tells the server which device to push to for the signed-in account
/// (`device-tokens`).
class PushRegistration {
  PushRegistration(
    this._client, {
    required Future<String?> Function() token,
    required Stream<String> tokenRefreshes,
    this.deviceType = 'android',
  }) : _token = token,
       _tokenRefreshes = tokenRefreshes;

  final ApiClient _client;
  final Future<String?> Function() _token;
  final Stream<String> _tokenRefreshes;
  final String deviceType;

  StreamSubscription<String>? _refreshes;

  /// The token registered for this session.
  String? _registered;

  /// Registers this device; does nothing when push is off.
  Future<void> register() async {
    final token = await _token();
    if (token == null) return;
    await _send(token);
    _refreshes ??= _tokenRefreshes.listen(_send);
  }

  /// Stops pushes to this device. Call before the session token is dropped.
  Future<void> unregister() async {
    await _refreshes?.cancel();
    _refreshes = null;
    final token = _registered;
    _registered = null;
    if (token == null) return;
    try {
      await _client.delete('device-tokens', {'token': token});
    } on ApiException catch (e) {
      AppLog.warn('PUSH', 'Device token not removed', e);
    }
  }

  Future<void> _send(String token) async {
    try {
      await _client.post('device-tokens', {
        'token': token,
        'device_type': deviceType,
      });
      _registered = token;
    } on ApiException catch (e) {
      AppLog.warn('PUSH', 'Device token not registered', e);
    }
  }

  void dispose() => _refreshes?.cancel();
}
