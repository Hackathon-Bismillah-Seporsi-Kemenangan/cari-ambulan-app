import 'package:cari_ambulan_app/features/auth/domain/auth_models.dart';
import 'package:cari_ambulan_app/features/auth/presentation/pages/login_page.dart';
import 'package:cari_ambulan_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:cari_ambulan_app/features/driver/domain/driver_models.dart';
import 'package:cari_ambulan_app/features/driver/presentation/pages/driver_shell.dart';
import 'package:cari_ambulan_app/features/driver/presentation/providers/driver_home_provider.dart';
import 'package:cari_ambulan_app/features/user/presentation/pages/user_shell.dart';
import 'package:cari_ambulan_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auth Domain Model Tests', () {
    test('AuthUser correctly identifies driver role', () {
      final user = AuthUser.fromJson({
        'id': 'uuid-driver-1',
        'full_name': 'Budi Santoso',
        'email': 'driver@cariambulan.id',
        'phone': '081200001199',
        'roles': ['driver'],
      });

      expect(user.id, 'uuid-driver-1');
      expect(user.fullName, 'Budi Santoso');
      expect(user.isDriver, isTrue);
      expect(user.isUser, isFalse);
    });

    test('AuthUser correctly identifies user/patient role', () {
      final user = AuthUser.fromJson({
        'id': 'uuid-patient-1',
        'full_name': 'Siti Rahmawati',
        'email': 'pasien@cariambulan.id',
        'phone': '081234567890',
        'roles': ['user'],
      });

      expect(user.isDriver, isFalse);
      expect(user.isUser, isTrue);
    });
  });

  group('Widget & UI Tests', () {
    testWidgets('LoginPage renders correctly when unauthenticated', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: LoginPage()),
        ),
      );

      expect(find.text('CariAmbulan'), findsOneWidget);
      expect(find.text('Masuk'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('AuthGate displays DriverShell when driver is logged in', (tester) async {
      const driver = AuthUser(
        id: 'driver-123',
        fullName: 'Pak Supir',
        email: 'driver@cariambulan.id',
        roles: ['driver'],
      );

      const driverProfile = DriverProfile(
        id: 'driver-123',
        name: 'Pak Supir',
        vehiclePlate: 'B 1199 SGM',
        vehicleType: 'Ambulans ALS',
        hospitalName: 'RS Medika',
        availabilityStatus: DriverAvailability.offline,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(driver)),
            driverHomeProvider.overrideWith(
              () => _FakeDriverHomeNotifier(
                const DriverHomeState(profile: driverProfile),
              ),
            ),
          ],
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DriverShell), findsOneWidget);
      expect(find.text('Pak Supir'), findsOneWidget);
      expect(find.text('TIDAK AKTIF (OFFLINE)'), findsOneWidget);
    });

    testWidgets('AuthGate displays UserShell when patient is logged in', (tester) async {
      const patient = AuthUser(
        id: 'patient-123',
        fullName: 'Ibu Pasien',
        email: 'pasien@cariambulan.id',
        roles: ['user'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(patient)),
          ],
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UserShell), findsOneWidget);
      expect(find.text('Halo, Ibu Pasien!'), findsOneWidget);
    });
  });
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._initialUser);

  final AuthUser? _initialUser;

  @override
  Future<AuthUser?> build() async => _initialUser;
}

class _FakeDriverHomeNotifier extends DriverHomeNotifier {
  _FakeDriverHomeNotifier(this._initialState);

  final DriverHomeState _initialState;

  @override
  Future<DriverHomeState> build() async => _initialState;
}
