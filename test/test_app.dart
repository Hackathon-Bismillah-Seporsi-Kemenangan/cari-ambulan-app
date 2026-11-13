import 'package:cari_ambulan/core/permissions/access_permissions.dart';
import 'package:cari_ambulan/features/auth/domain/auth_models.dart';
import 'package:cari_ambulan/features/auth/presentation/providers/auth_provider.dart';
import 'package:cari_ambulan/features/driver/data/driver_repository.dart';
import 'package:cari_ambulan/features/driver/data/mock_driver_repository.dart';
import 'package:cari_ambulan/features/driver/presentation/providers/driver_home_provider.dart';
import 'package:cari_ambulan/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

const testDriver = AuthUser(
  id: 'driver-1',
  fullName: 'Budi Santoso',
  email: 'driver@cariambulan.id',
  roles: ['driver'],
);

/// The app signed in as [user], on the mock backend.
Widget testApp({
  AuthUser? user = testDriver,
  AccessPermissions? permissions,
  DriverRepository? driverRepository,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(() => FakeAuth(user)),
      driverRepositoryProvider.overrideWith(
        (ref) => driverRepository ?? MockDriverRepository(),
      ),
      accessPermissionsProvider.overrideWithValue(
        permissions ?? FakePermissions(),
      ),
      ...overrides,
    ],
    child: const CariAmbulanApp(),
  );
}

class FakeAuth extends AuthNotifier {
  FakeAuth(this._user);

  final AuthUser? _user;

  @override
  Future<AuthUser?> build() async => _user;

  @override
  Future<void> logout() async => state = const AsyncData(null);
}

/// Android permissions, granted by the "user" as soon as they are asked.
class FakePermissions extends AccessPermissions {
  FakePermissions();

  bool location = false;
  bool notifications = false;

  /// What was asked, in order.
  final asked = <String>[];

  @override
  Future<bool> hasLocation() async => location;

  @override
  Future<bool> hasNotifications() async => notifications;

  @override
  Future<bool> requestLocation() async {
    asked.add('location');
    return location = true;
  }

  @override
  Future<bool> requestNotifications() async {
    asked.add('notifications');
    return notifications = true;
  }
}
