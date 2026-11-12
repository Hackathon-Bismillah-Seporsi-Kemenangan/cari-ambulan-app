import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../alerts/emergency_alert.dart';
import '../logging/app_log.dart';

/// Firebase settings, given at build time so no project config is committed:
///
/// ```sh
/// flutter run \
///   --dart-define=FIREBASE_API_KEY=... \
///   --dart-define=FIREBASE_APP_ID=1:...:android:... \
///   --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
///   --dart-define=FIREBASE_PROJECT_ID=...
/// ```
///
/// Left out, push is off and calls and orders arrive by polling only.
abstract final class PushConfig {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _senderId.isNotEmpty &&
      _projectId.isNotEmpty;

  static const options = FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _senderId,
    projectId: _projectId,
  );
}

/// What a push from the server is about (its `data.type`).
enum PushKind {
  /// The other side of the trip is calling.
  incomingCall,

  /// A new order for a driver.
  emergencyOffer,
}

PushKind? pushKindOf(Map<String, dynamic> data) => switch (data['type']) {
  'incoming_call' => PushKind.incomingCall,
  'emergency_offer' => PushKind.emergencyOffer,
  _ => null,
};

/// The notification shown for a push while the app is closed.
({String title, String body})? pushAlertFor(Map<String, dynamic> data) {
  switch (pushKindOf(data)) {
    case PushKind.incomingCall:
      final caller = data['caller_name'] as String?;
      return (
        title: 'Panggilan masuk',
        body:
            '${caller == null || caller.isEmpty ? 'Lawan bicara' : caller} '
            'menelepon Anda. Ketuk untuk menjawab.',
      );
    case PushKind.emergencyOffer:
      return (
        title: 'Order darurat baru',
        body:
            'Ada pasien membutuhkan ambulans di dekat Anda. Ketuk untuk '
            'melihat.',
      );
    case null:
      return null;
  }
}

/// Runs in its own isolate while the app is in the background or closed.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  final alert = pushAlertFor(message.data);
  if (alert == null) return;
  await EmergencyAlert.notify(title: alert.title, body: alert.body);
}

/// Firebase Cloud Messaging: wakes the app for calls and orders.
///
/// The server sends data-only messages; the app still asks the API for the
/// details, so a push only makes that happen sooner.
abstract final class PushService {
  static bool _started = false;
  static final _messages = StreamController<PushKind>.broadcast();

  /// Pushes received while the app is open, or tapped to open it.
  static Stream<PushKind> get messages => _messages.stream;

  static bool get isEnabled => _started;

  /// Starts push when [PushConfig] is set; otherwise does nothing.
  static Future<void> init() async {
    if (_started || !PushConfig.isConfigured || kIsWeb) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: PushConfig.options);
      }
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
      FirebaseMessaging.onMessage.listen(_dispatch);
      FirebaseMessaging.onMessageOpenedApp.listen(_dispatch);
      await FirebaseMessaging.instance.requestPermission();
      _started = true;
      AppLog.info('PUSH', 'Firebase Messaging ready');
    } catch (e) {
      AppLog.warn('PUSH', 'Push disabled: Firebase failed to start', e);
    }
  }

  /// This device's FCM registration token, or null when push is off.
  ///
  /// The server sends to registration tokens (`message.token`), not to the
  /// installation IDs of the newer register() / onRegistered API.
  static Future<String?> token() async {
    if (!_started) return null;
    try {
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      AppLog.warn('PUSH', 'No FCM token', e);
      return null;
    }
  }

  /// New tokens issued by Firebase; empty when push is off.
  static Stream<String> get tokenRefreshes => _started
      // ignore: deprecated_member_use
      ? FirebaseMessaging.instance.onTokenRefresh
      : const Stream.empty();

  static String get deviceType => Platform.isIOS ? 'ios' : 'android';

  static void _dispatch(RemoteMessage message) {
    final kind = pushKindOf(message.data);
    AppLog.info('PUSH', 'Message: ${message.data['type']}');
    if (kind != null) _messages.add(kind);
  }
}
