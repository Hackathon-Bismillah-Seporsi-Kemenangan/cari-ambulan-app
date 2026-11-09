import 'package:cari_ambulan_app/core/location/location_service.dart';
import 'package:cari_ambulan_app/features/driver/data/driver_repository.dart';
import 'package:cari_ambulan_app/features/driver/data/routing_repository.dart';
import 'package:cari_ambulan_app/features/driver/domain/dispatch_offer_model.dart';
import 'package:cari_ambulan_app/features/driver/domain/driver_models.dart';
import 'package:cari_ambulan_app/features/driver/domain/route_models.dart';
import 'package:cari_ambulan_app/features/driver/presentation/pages/trip_navigation_page.dart';
import 'package:cari_ambulan_app/features/driver/presentation/providers/driver_home_provider.dart';
import 'package:cari_ambulan_app/features/emergency/domain/emergency_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const _driver = LatLng(-6.2000, 106.8100);
const _pickup = EmergencyLocation(
  latitude: -6.2088,
  longitude: 106.8222,
  address: 'Jl. Sudirman No. 10',
);
const _hospital = HospitalInfo(
  name: 'RSUD Tarakan',
  latitude: -6.1710,
  longitude: 106.8100,
  ambulanceEntrance: 'Gerbang B',
);

EmergencyRequestModel _trip(EmergencyRequestStatus status) =>
    EmergencyRequestModel(
      id: 'req-1',
      requestCode: 'CA-NAV1',
      status: status,
      pickup: _pickup,
      emergencyType: 'Jantung',
      reporterName: 'Budi Santoso',
      reporterPhone: '08123',
      bloodType: 'O',
      isHighPriority: true,
      hospital:
          status == EmergencyRequestStatus.enRouteToHospital ||
              status == EmergencyRequestStatus.completed
          ? _hospital
          : null,
      hospitalPreparation: 'IGD menyiapkan tim jantung.',
    );

class _TripRepo implements DriverRepository {
  EmergencyRequestModel? trip = _trip(EmergencyRequestStatus.enRouteToPickup);
  final calls = <String>[];

  Future<EmergencyRequestModel> _moveTo(
    String call,
    EmergencyRequestStatus status,
  ) async {
    calls.add(call);
    final next = _trip(status);
    trip = status == EmergencyRequestStatus.completed ? null : next;
    return next;
  }

  @override
  Future<EmergencyRequestModel?> getActiveTrip() async => trip;

  @override
  Future<List<DriverTripHistoryItem>> fetchTripHistory() async => const [];

  @override
  Future<({String fullName, String? phone})> updateAccount({
    required String fullName,
    required String phone,
  }) async => (fullName: fullName, phone: phone);

  @override
  Future<EmergencyRequestModel> markArrived(String requestId) =>
      _moveTo('arrive', EmergencyRequestStatus.arriveAtPickup);

  @override
  Future<EmergencyRequestModel> startToHospital(String requestId) =>
      _moveTo('start-to-hospital', EmergencyRequestStatus.enRouteToHospital);

  @override
  Future<EmergencyRequestModel> completeTrip(String requestId) =>
      _moveTo('complete', EmergencyRequestStatus.completed);

  @override
  Future<DriverProfile> fetchProfile() async => const DriverProfile(
    id: 'drv-1',
    name: 'Driver',
    vehiclePlate: 'B 1234 CA',
    vehicleType: 'Ambulans ALS',
    availabilityStatus: DriverAvailability.busy,
  );

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
}

class _StraightRouting implements RoutingRepository {
  @override
  Future<DriveRoute> fetchRoute(LatLng from, LatLng to) async => DriveRoute(
    points: [from, to],
    distanceMeters: 1800,
    duration: const Duration(minutes: 5),
    steps: [
      RouteStep(
        maneuver: Maneuver.depart,
        streetName: '',
        distanceMeters: 300,
        location: from,
      ),
      RouteStep(
        maneuver: Maneuver.right,
        streetName: 'Jl. Thamrin',
        distanceMeters: 1500,
        location: from,
      ),
    ],
  );
}

/// The ambulance marker pulses forever, so wait a fixed time instead of
/// pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('drives a trip from pickup to IGD handover', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final repo = _TripRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverRepositoryProvider.overrideWithValue(repo),
          routingRepositoryProvider.overrideWithValue(_StraightRouting()),
          liveLocationProvider.overrideWith((ref) => Stream.value(_driver)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => TripNavigationPage.open(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);

    // To the patient, with turn-by-turn directions.
    expect(find.text('Menuju pasien'), findsOneWidget);
    expect(find.text('Belok kanan ke Jl. Thamrin'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Prioritas Tinggi'), findsOneWidget);

    await tester.tap(find.text('Saya Sudah Tiba'));
    await _settle(tester);
    expect(find.text('Tiba di lokasi pasien'), findsOneWidget);

    await tester.tap(find.text('Mulai ke Rumah Sakit'));
    await _settle(tester);

    // To the hospital, whose IGD was alerted.
    expect(find.text('Menuju rumah sakit'), findsWidgets);
    expect(find.text('RSUD Tarakan sudah diberi tahu'), findsOneWidget);
    expect(
      find.text('IGD menyiapkan tim jantung. Pintu masuk ambulans: Gerbang B.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Serahkan Pasien ke IGD'));
    await _settle(tester);
    await tester.tap(find.text('Ya, Serahkan'));
    await _settle(tester);

    expect(repo.calls, ['arrive', 'start-to-hospital', 'complete']);
    // Back on the previous screen once the order is closed.
    expect(find.byType(TripNavigationPage), findsNothing);
    expect(
      find.text('Order selesai. Anda kembali online. Terima kasih!'),
      findsOneWidget,
    );
  });

  testWidgets('back button cannot leave an accepted trip', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverRepositoryProvider.overrideWithValue(_TripRepo()),
          routingRepositoryProvider.overrideWithValue(_StraightRouting()),
          liveLocationProvider.overrideWith((ref) => Stream.value(_driver)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => TripNavigationPage.open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);

    final popped = await tester.binding.handlePopRoute();
    await _settle(tester);

    expect(popped, isTrue);
    expect(find.byType(TripNavigationPage), findsOneWidget);
  });
}
