import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../logging/app_log.dart';
import '../permissions/permission_requests.dart';

/// Shows the app over the lock screen, like an incoming phone call, while
/// something needs the user: a ringing order or call, or a call in progress.
///
/// Only while held: at any other time a locked phone hides the app, so a
/// Medical ID or trip left open can't be read without unlocking.
abstract final class LockScreen {
  /// MainActivity.kt.
  static const _channel = MethodChannel('cari_ambulan/lock_screen');

  static final _reasons = <String>{};

  @visibleForTesting
  static Set<String> get reasons => Set.unmodifiable(_reasons);

  /// Keeps the app over the lock screen until [reason] is released.
  static Future<void> hold(String reason) async {
    if (!_reasons.add(reason) || _reasons.length > 1) return;
    await _invoke('show');
  }

  static Future<void> release(String reason) async {
    if (!_reasons.remove(reason) || _reasons.isNotEmpty) return;
    await _invoke('hide');
  }

  /// Whether a ringing order or call may open over the lock screen. Android
  /// 14+ lets the user turn this off; null when unknown (tests, iOS).
  static Future<bool?> canRing() async {
    try {
      return await _channel.invokeMethod<bool>('canRing');
    } on MissingPluginException {
      return null;
    } catch (e) {
      AppLog.warn('ALERT', 'Full-screen check failed', e);
      return null;
    }
  }

  /// Opens the Android setting that allows it.
  static Future<void> allowRinging() async {
    try {
      await PermissionRequests.run(
        () async => FlutterLocalNotificationsPlugin()
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestFullScreenIntentPermission(),
      );
    } catch (e) {
      AppLog.warn('ALERT', 'Full-screen setting failed', e);
    }
  }

  static Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Widget tests and platforms without MainActivity.
    } catch (e) {
      AppLog.warn('ALERT', 'Lock screen $method failed', e);
    }
  }
}
