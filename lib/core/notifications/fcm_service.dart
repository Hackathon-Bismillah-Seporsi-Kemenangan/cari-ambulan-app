import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../alerts/emergency_alert.dart';
import '../logging/app_log.dart';
import '../network/api_client.dart';
import '../../features/call/domain/call_models.dart';

/// Top-level background message handler required by FirebaseMessaging.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}

  final data = message.data;
  AppLog.info('FCM', 'Background message received: $data');

  if (data['type'] == 'incoming_call' || data.containsKey('call_id')) {
    final callerName = (data['caller_name'] as String?)?.isNotEmpty == true
        ? data['caller_name'] as String
        : 'Panggilan Darurat';
    await EmergencyAlert.start(
      title: 'Panggilan Masuk: $callerName',
      body: 'Ketuk untuk menjawab panggilan suara darurat.',
      background: true,
      data: Map<String, dynamic>.from(data),
    );
  } else if (data['type'] == 'emergency_offer') {
    // A new order for a driver whose app is closed; they have ~30 s.
    await EmergencyAlert.start(
      title: 'Order darurat baru',
      body:
          'Ada pasien membutuhkan ambulans di dekat Anda. Ketuk untuk melihat.',
      background: true,
      data: Map<String, dynamic>.from(data),
    );
  }
}

class FcmService {
  static bool _initialized = false;
  static void Function(IncomingCall call)? onIncomingCall;

  /// A call that arrived (e.g. launched the app from the lock screen) before
  /// anyone was listening; the call provider takes it once it exists.
  static IncomingCall? pendingCall;

  /// Initializes Firebase and Firebase Cloud Messaging listeners.
  /// Safely catches missing configuration if google-services.json is not present yet.
  static Future<void> init() async {
    if (_initialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request notification permissions (required on iOS and Android 13+)
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      AppLog.info(
        'FCM',
        'Notification permission status: ${settings.authorizationStatus}',
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        AppLog.info('FCM', 'Foreground message received: ${message.data}');
        _handleMessage(message);
      });

      // Handle message when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        AppLog.info('FCM', 'App opened from notification: ${message.data}');
        _handleMessage(message);
      });

      // Check if opened from a terminated state
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        AppLog.info(
          'FCM',
          'App launched from terminated notification: ${initialMessage.data}',
        );
        _handleMessage(initialMessage);
      }

      // Tapping / full-screen launching from the ringing notification.
      EmergencyAlert.onOpened = (data) {
        EmergencyAlert.stop();
        _dispatch(data);
      };
      await EmergencyAlert.init();
      final launched = await EmergencyAlert.launchData();
      if (launched != null) _dispatch(launched);

      _initialized = true;
    } catch (e) {
      AppLog.warn('FCM', 'FCM initialization skipped or failed: $e');
    }
  }

  /// Retrieves device FCM token to register with the backend.
  static Future<String?> getToken() async {
    try {
      if (!_initialized) await init();
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      AppLog.info('FCM', 'Device token: $token');
      return token;
    } catch (e) {
      AppLog.warn('FCM', 'Failed to retrieve FCM token: $e');
      return null;
    }
  }

  /// Sends device FCM token to Laravel backend.
  static Future<void> syncTokenWithBackend(ApiClient client) async {
    final token = await getToken();
    if (token == null || token.isEmpty) return;

    try {
      await client.post('device-tokens', {
        'token': token,
        'device_type': 'android',
      });
      AppLog.info('FCM', 'FCM token synced with server');
    } catch (e) {
      AppLog.warn('FCM', 'Failed to sync FCM token with server: $e');
    }
  }

  static void _handleMessage(RemoteMessage message) => _dispatch(message.data);

  static void _dispatch(Map<String, dynamic> data) {
    if (data['type'] == 'incoming_call' ||
        data.containsKey('call_id') ||
        data.containsKey('id')) {
      final call = IncomingCall.fromJson(data);
      if (call.id.isEmpty) return;
      // The call panel takes over from the ringing notification.
      EmergencyAlert.stop();
      final listener = onIncomingCall;
      if (listener != null) {
        listener(call);
      } else {
        pendingCall = call;
      }
    }
  }
}
