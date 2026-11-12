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

  /// A push while the app is closed: the OS plays the sound and vibration,
  /// since nothing in the app is running to stop a loop.
  static const _pushChannel = AndroidNotificationDetails(
    'push_alerts',
    'Panggilan & order masuk',
    channelDescription: 'Panggilan dan order darurat saat aplikasi tertutup',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.call,
    visibility: NotificationVisibility.public,
    autoCancel: true,
    // Calls ring out and offers expire after about 30 s.
    timeoutAfter: 45000,
    color: Color(0xFFD32F2F),
  );

  static const _pushNotificationId = 1002;

  /// Three hard bursts, then a short pause, repeated: an urgent rhythm a
  /// driver feels even with the phone in a pocket or a dashboard mount.
  static const _vibrationPattern = [0, 500, 120, 500, 120, 500, 500];
  static const _vibrationIntensities = [0, 255, 0, 255, 0, 255, 0];

  /// Sets up notifications and asks for the Android 13+ permission. Call
  /// once the driver is signed in.
  static Future<void> init() async {
    if (_initialized) return;
    await _guard(() async {
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      await PermissionRequests.run(
        () async => _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission(),
      );
      _initialized = true;
    });
  }

  /// Returns false when the device can't play the vibration pattern, so the
  /// caller can fall back to haptic taps.
  static Future<bool> start({
    required String title,
    required String body,
  }) async {
    _active = true;
    final (_, _, vibrating) = await (
      _guard(() => _ringtone.invokeMethod<void>('play')),
      _guard(() async {
        await init();
        await _notifications.show(
          id: _notificationId,
          title: title,
          body: body,
          notificationDetails: const NotificationDetails(
            android: _channel,
            iOS: DarwinNotificationDetails(
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
        );
      }),
      _startVibration(),
    ).wait;
    // The driver answered before everything started.
    if (!_active) await stop();
    return vibrating;
  }

  /// Shows a one-off heads-up notification; tapping it opens the app, which
  /// then finds the call or order by polling. Safe in a background isolate.
  static Future<void> notify({
    required String title,
    required String body,
  }) async {
    await _guard(() async {
      await init();
      await _notifications.show(
        id: _pushNotificationId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: _pushChannel,
          iOS: DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
      );
    });
  }

  static Future<void> stop() async {
    _active = false;
    await Future.wait([
      _guard(() => _ringtone.invokeMethod<void>('stop')),
      _guard(Vibration.cancel),
      _guard(() => _notifications.cancel(id: _notificationId)),
      _guard(() => _notifications.cancel(id: _pushNotificationId)),
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
      AppLog.warn('ALERT', 'Alarm sound/vibration failed', e);
    }
  }
}
