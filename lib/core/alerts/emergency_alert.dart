import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import '../logging/app_log.dart';
import '../permissions/permission_requests.dart';

/// Rings the driver for a new emergency order: looping siren, urgent
/// vibration and a heads-up notification, until [stop].
///
/// Every part is best effort: a missing plugin (widget tests) or a denied
/// permission skips that part instead of failing the call screen.
abstract final class EmergencyAlert {
  static final _notifications = FlutterLocalNotificationsPlugin();

  /// Loops the siren at full alarm volume (MainActivity.kt).
  static const _ringtone = MethodChannel('cari_ambulan/ringtone');
  static bool _initialized = false;

  /// False once [stop] runs, so a [start] still in progress cleans up.
  static bool _active = false;

  static const _notificationId = 1001;

  /// Ringtone and vibration are played by [start], so the channel is silent.
  static const _channel = AndroidNotificationDetails(
    'emergency_calls',
    'Panggilan darurat',
    channelDescription: 'Order darurat baru untuk pengemudi ambulans',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.call,
    visibility: NotificationVisibility.public,
    playSound: false,
    enableVibration: false,
    ongoing: true,
    autoCancel: true,
    color: Color(0xFFD32F2F),
    ticker: 'Panggilan darurat',
  );

  /// Incoming-call style, like WhatsApp: for a push that arrives with the app
  /// closed or in the background. The in-app siren (MainActivity.kt) isn't
  /// reachable from that isolate, so this channel rings by itself (alarm
  /// sound, vibration) and its full-screen intent wakes the screen and opens
  /// the app over the lock screen.
  static const _backgroundChannel = AndroidNotificationDetails(
    'incoming_call_ring',
    'Panggilan masuk',
    channelDescription: 'Panggilan dan order darurat saat aplikasi tertutup',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.call,
    visibility: NotificationVisibility.public,
    playSound: true,
    enableVibration: true,
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    fullScreenIntent: true,
    timeoutAfter: 30000,
    autoCancel: true,
    color: Color(0xFFD32F2F),
    ticker: 'Panggilan masuk',
  );

  /// Called with the push data when the user taps the ringing notification
  /// (or it opens the app full screen).
  static void Function(Map<String, dynamic> data)? onOpened;

  /// The push that launched a closed app, if any.
  static Future<Map<String, dynamic>?> launchData() async {
    try {
      final details = await _notifications.getNotificationAppLaunchDetails();
      final payload = details?.notificationResponse?.payload;
      if (details?.didNotificationLaunchApp == true && payload != null) {
        return Map<String, dynamic>.from(jsonDecode(payload) as Map);
      }
    } catch (_) {}
    return null;
  }

  /// Three hard bursts, then a short pause, repeated: an urgent rhythm a
  /// driver feels even with the phone in a pocket or a dashboard mount.
  static const _vibrationPattern = [0, 500, 120, 500, 120, 500, 500];
  static const _vibrationIntensities = [0, 255, 0, 255, 0, 255, 0];

  /// Sets up notifications and asks for the Android 13+ permission. Call
  /// once the driver is signed in.
  ///
  /// [requestPermission] is false from a push handler with the app closed:
  /// there is no Activity there to show the permission dialog.
  static Future<void> init({bool requestPermission = true}) async {
    if (_initialized) return;
    await _guard(() async {
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null) return;
          try {
            onOpened?.call(
              Map<String, dynamic>.from(jsonDecode(payload) as Map),
            );
          } catch (_) {}
        },
      );
      if (requestPermission) {
        await PermissionRequests.run(
          () async => _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission(),
        );
      }
      _initialized = true;
    });
  }

  /// Returns false when the device can't play the vibration pattern, so the
  /// caller can fall back to haptic taps.
  static Future<bool> start({
    required String title,
    required String body,
    bool background = false,
    Map<String, dynamic>? data,
  }) async {
    _active = true;
    final (_, _, vibrating) = await (
      background
          ? Future.value()
          : _guard(() => _ringtone.invokeMethod<void>('play')),
      _guard(() async {
        await init(requestPermission: !background);
        await _notifications.show(
          id: _notificationId,
          title: title,
          body: body,
          payload: data == null ? null : jsonEncode(data),
          notificationDetails: NotificationDetails(
            android: background ? _backgroundChannel : _channel,
            iOS: DarwinNotificationDetails(
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
        );
      }),
      // The ringing channel vibrates by itself.
      background ? Future.value(false) : _startVibration(),
    ).wait;
    // The driver answered before everything started.
    if (!_active) await stop();
    return vibrating;
  }

  static Future<void> stop() async {
    _active = false;
    await Future.wait([
      _guard(() => _ringtone.invokeMethod<void>('stop')),
      _guard(Vibration.cancel),
      _guard(() => _notifications.cancel(id: _notificationId)),
    ]);
  }

  static Future<bool> _startVibration() async {
    var vibrating = false;
    await _guard(() async {
      if (!await Vibration.hasVibrator()) return;
      await Vibration.vibrate(
        pattern: _vibrationPattern,
        intensities: _vibrationIntensities,
        repeat: 0,
      );
      vibrating = true;
    });
    return vibrating;
  }

  static Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on MissingPluginException {
      // Widget tests and unsupported platforms.
    } catch (e) {
      AppLog.warn('Alert', 'Alarm sound/vibration failed', e);
    }
  }
}
