import 'package:cari_ambulan_app/features/auth/domain/auth_models.dart';
import 'package:cari_ambulan_app/features/driver/data/driver_repository.dart';
import 'package:cari_ambulan_app/features/driver/domain/dispatch_offer_model.dart';
import 'package:cari_ambulan_app/features/driver/domain/driver_models.dart';
import 'package:cari_ambulan_app/features/driver/presentation/pages/driver_shell.dart';
import 'package:cari_ambulan_app/features/driver/presentation/pages/incoming_call_page.dart';
import 'package:cari_ambulan_app/features/driver/presentation/providers/driver_home_provider.dart';
import 'package:cari_ambulan_app/features/driver/presentation/providers/driver_trip_provider.dart';
import 'package:cari_ambulan_app/features/emergency/domain/emergency_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _offerJson = {
  'id': 7,
  'status': 'offered',
  'distance_km': 2.4,
  'eta_minutes': 6,
  'offered_at': '2026-11-09T10:00:00+07:00',
  'expires_at': '2026-11-09T10:00:30+07:00',
  'seconds_remaining': 25,
  'nearest_hospital': {'id': 'h-1', 'name': 'RSUD Tarakan'},
  'request': {
    'id': 'req-9',
    'code': 'CA-CALL1',
    'emergency_type': 'Jantung',
    'patient_notes': 'Nyeri dada sejak pagi',
    'pickup': {
      'latitude': -6.2088,
      'longitude': 106.8222,
      'address': 'Jl. Sudirman No. 10',
    },
    'reporter': {'name': 'Budi Santoso', 'phone': '08123'},
    'medical': {'blood_type': 'O'},
  },
};

class _CallRepo implements DriverRepository {
  DispatchOfferModel? offer = DispatchOfferModel.fromJson(_offerJson);
  final calls = <String>[];

  @override
  Future<DispatchOfferModel?> getCurrentOffer() async => offer;

  @override
  Future<EmergencyRequestModel> acceptRequest(String requestId) async {
    calls.add('accept $requestId');
    offer = null;
    return EmergencyRequestModel(
      id: requestId,
      requestCode: 'CA-CALL1',
      status: EmergencyRequestStatus.enRouteToPickup,
      pickup: const EmergencyLocation(
        latitude: -6.2088,
        longitude: 106.8222,
        address: 'Jl. Sudirman No. 10',
      ),
    );
  }

  @override
  Future<void> declineRequest(String requestId) async {
    calls.add('decline $requestId');
    offer = null;
  }

  @override
  Future<DriverProfile> fetchProfile() async => const DriverProfile(
        id: 'drv-1',
        name: 'Driver',
        vehiclePlate: 'B 1234 CA',
        vehicleType: 'Ambulans ALS',
        availabilityStatus: DriverAvailability.online,
      );

  @override
  Future<DriverProfile> setAvailability(
    DriverAvailability availability, {
    double? latitude,
    double? longitude,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> sendLocation(double latitude, double longitude) async {}

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

/// The countdown ring and map marker animate forever, so wait a fixed time
/// instead of pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<ProviderContainer> _pumpShell(WidgetTester tester, _CallRepo repo) async {
  // Wide enough for the test font, whose glyphs are all full squares.
  tester.view.physicalSize = const Size(1800, 3000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [driverRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        home: DriverShell(
          user: AuthUser(id: 'u-1', fullName: 'Driver', roles: ['driver']),
        ),
      ),
    ),
  );
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

void main() {
  test('DispatchOfferModel reads ETA, nearest hospital and window', () {
    final offer = DispatchOfferModel.fromJson(_offerJson);

    expect(offer.emergencyRequestId, 'req-9');
    expect(offer.etaMinutes, 6);
    expect(offer.nearestHospitalName, 'RSUD Tarakan');
    expect(offer.bloodType, 'O');
    expect(offer.offerWindow, const Duration(seconds: 30));
  });

  testWidgets('an offer rings full-screen and accepting starts the trip',
      (tester) async {
    final repo = _CallRepo();
    final container = await _pumpShell(tester, repo);

    expect(find.byType(IncomingCallPage), findsOneWidget);
    expect(find.text('PANGGILAN DARURAT'), findsOneWidget);
    expect(find.text('Jl. Sudirman No. 10'), findsOneWidget);
    expect(find.text('6 menit'), findsOneWidget);
    expect(find.text('RSUD Tarakan'), findsOneWidget);

    await tester.tap(find.text('Terima'));
    await _settle(tester);

    expect(repo.calls, ['accept req-9']);
    expect(find.byType(IncomingCallPage), findsNothing);
    expect(container.read(driverTripProvider).trip?.id, 'req-9');
  });

  testWidgets('declining closes the call', (tester) async {
    final repo = _CallRepo();
    final container = await _pumpShell(tester, repo);

    await tester.tap(find.text('Tolak'));
    await _settle(tester);

    expect(repo.calls, ['decline req-9']);
    expect(find.byType(IncomingCallPage), findsNothing);
    expect(container.read(driverTripProvider).hasActiveTrip, isFalse);
  });
}
