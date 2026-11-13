import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../alerts/emergency_alert.dart';
import '../logging/app_log.dart';
import 'permission_requests.dart';

/// The permissions asked after the introduction: location for everyone,
/// and for drivers notifications (the emergency call). Every call is best
/// effort and reports false when the platform can't answer.
class AccessPermissions {
  const AccessPermissions();

  Future<bool> hasLocation() => _check(() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  });

  Future<bool> requestLocation() => _check(() async {
    final permission = await PermissionRequests.run(
      Geolocator.requestPermission,
    );
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  });

  Future<bool> hasNotifications() => _check(
    () async =>
        await FlutterLocalNotificationsPlugin()
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        true,
  );

  /// Also sets up the call notification channel.
  Future<bool> requestNotifications() async {
    await EmergencyAlert.init();
    return hasNotifications();
  }

  static Future<bool> _check(Future<bool> Function() check) async {
    try {
      return await check();
    } catch (e) {
      AppLog.warn('Izin', 'Permission unavailable', e);
      return false;
    }
  }
}

final accessPermissionsProvider = Provider((ref) => const AccessPermissions());
