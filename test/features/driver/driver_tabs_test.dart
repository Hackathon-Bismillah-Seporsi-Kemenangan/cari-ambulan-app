import 'package:cari_ambulan_app/features/auth/domain/auth_models.dart';
import 'package:cari_ambulan_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:cari_ambulan_app/features/driver/data/driver_repository.dart';
import 'package:cari_ambulan_app/features/driver/domain/dispatch_offer_model.dart';
import 'package:cari_ambulan_app/features/driver/domain/driver_models.dart';
import 'package:cari_ambulan_app/features/driver/presentation/pages/driver_shell.dart';
import 'package:cari_ambulan_app/features/driver/presentation/providers/driver_home_provider.dart';
import 'package:cari_ambulan_app/features/emergency/domain/emergency_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = AuthUser(
  id: 'u-1',
  fullName: 'Budi Santoso',
  phone: '08123',
  roles: ['driver'],
);

/// Signed in as [_user]; edits stay in memory instead of secure storage.
class _FakeAuth extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => _user;

  @override
  Future<void> updateUser(AuthUser user) async => state = AsyncData(user);
}

class _TabsRepo implements DriverRepository {
  final calls = <String>[];

  @override
  Future<DriverProfile> fetchProfile() async => const DriverProfile(
    id: 'drv-1',
    name: 'Budi Santoso',
    vehiclePlate: 'B 1199 SGM',
    vehicleType: 'Ambulans ALS',
    licenseNumber: 'SIM-31750001',
    hospitalName: 'RS Medika',
    completedTripsToday: 2,
  );

  @override
  Future<List<DriverTripHistoryItem>> fetchTripHistory() async {
    calls.add('history');
    return [
      DriverTripHistoryItem(
        id: '12',
        code: 'CA-DONE1',
        status: 'completed',
        emergencyType: 'Jantung',
        pickupAddress: 'Jl. Sudirman No. 10',
        requestedAt: DateTime(2026, 11, 9, 10),
        patientName: 'Siti',
        hospitalName: 'RSUD Tarakan',
        completedAt: DateTime(2026, 11, 9, 10, 40),
      ),
      DriverTripHistoryItem(
        id: '13',
        code: 'CA-STOP1',
        status: 'cancelled',
        emergencyType: 'Kecelakaan',
        pickupAddress: 'Jl. Thamrin',
        requestedAt: DateTime(2026, 11, 9, 11),
        cancelledAt: DateTime(2026, 11, 9, 11, 5),
      ),
    ];
  }

  @override
  Future<({String fullName, String? phone})> updateAccount({
    required String fullName,
    required String phone,
  }) async {
    calls.add('update $fullName $phone');
    return (fullName: fullName, phone: phone);
  }

  @override
  Future<DriverProfile> setAvailability(
    DriverAvailability availability, {
    double? latitude,
    double? longitude,
  }) async => throw UnimplementedError();

  @override
  Future<void> sendLocation(double latitude, double longitude) async {}

  @override
  Future<DispatchOfferModel?> getCurrentOffer() async => null;

  @override
  Future<EmergencyRequestModel> acceptRequest(String requestId) async =>
      throw UnimplementedError();

  @override
  Future<void> declineRequest(String requestId) async {}

  @override
  Future<EmergencyRequestModel?> getActiveTrip() async => null;

  @override
  Future<EmergencyRequestModel> markArrived(String requestId) async =>
      throw UnimplementedError();

  @override
  Future<EmergencyRequestModel> startToHospital(String requestId) async =>
      throw UnimplementedError();

  @override
  Future<EmergencyRequestModel> completeTrip(String requestId) async =>
      throw UnimplementedError();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<_TabsRepo> _pumpShell(WidgetTester tester) async {
  // Wide enough for the test font, whose glyphs are all full squares.
  tester.view.physicalSize = const Size(1800, 3000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  final repo = _TabsRepo();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        driverRepositoryProvider.overrideWithValue(repo),
        authProvider.overrideWith(_FakeAuth.new),
      ],
      child: const MaterialApp(home: DriverShell(user: _user)),
    ),
  );
  await _settle(tester);
  return repo;
}

void main() {
  testWidgets('Riwayat lists completed and cancelled trips', (tester) async {
    final repo = await _pumpShell(tester);

    await tester.tap(find.text('Riwayat'));
    await _settle(tester);

    expect(repo.calls, ['history']);
    expect(find.text('Jantung · #CA-DONE1'), findsOneWidget);
    expect(find.text('Kecelakaan · #CA-STOP1'), findsOneWidget);
    expect(find.text('RSUD Tarakan · Diserahkan 10:40'), findsOneWidget);
    expect(find.text('Dibatalkan pasien · 11:05'), findsOneWidget);
  });

  testWidgets('Profil shows the ambulance and saves an edited name', (
    tester,
  ) async {
    final repo = await _pumpShell(tester);

    await tester.tap(find.text('Profil'));
    await _settle(tester);

    expect(find.text('B 1199 SGM'), findsOneWidget);
    expect(find.text('SIM-31750001'), findsOneWidget);
    expect(find.text('Trip hari ini'), findsOneWidget);

    await tester.tap(find.byTooltip('Ubah profil'));
    await _settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Nama lengkap'),
      'Budi S.',
    );
    await tester.tap(find.text('Simpan'));
    await _settle(tester);

    expect(repo.calls, ['update Budi S. 08123']);
    expect(find.text('Budi S.'), findsOneWidget);
  });
}
