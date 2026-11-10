import 'package:cari_ambulan_app/core/location/location_service.dart';
import 'package:cari_ambulan_app/features/auth/domain/auth_models.dart';
import 'package:cari_ambulan_app/features/emergency/data/api_emergency_repository.dart';
import 'package:cari_ambulan_app/features/emergency/data/emergency_repository.dart';
import 'package:cari_ambulan_app/features/emergency/domain/emergency_models.dart';
import 'package:cari_ambulan_app/features/emergency/presentation/providers/emergency_provider.dart';
import 'package:cari_ambulan_app/features/emergency/presentation/widgets/assigned_driver_card.dart';
import 'package:cari_ambulan_app/features/emergency/presentation/widgets/searching_ambulance_view.dart';
import 'package:cari_ambulan_app/features/emergency/presentation/widgets/sos_button.dart';
import 'package:cari_ambulan_app/features/user/presentation/pages/user_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEmergencyRepository implements EmergencyRepository {
  EmergencyRequestModel? _current;
  final calls = <String>[];

  /// The search as the server returns it after widening or a retry.
  EmergencyRequestModel _search({
    required double radiusKm,
    bool exhausted = false,
  }) =>
      EmergencyRequestModel(
        id: _current!.id,
        requestCode: _current!.requestCode,
        status: EmergencyRequestStatus.searchingDriver,
        pickup: _current!.pickup,
        searchRadiusKm: radiusKm,
        isExhausted: exhausted,
        driversContacted: 2,
      );

  @override
  Future<EmergencyRequestModel> createEmergencyRequest({
    required double latitude,
    required double longitude,
    required String address,
    bool isForSelf = true,
    String? emergencyType,
    String? severityLevel,
    String? notes,
  }) async {
    _current = EmergencyRequestModel(
      id: 'req-123',
      requestCode: 'CA-TEST1',
      status: EmergencyRequestStatus.searchingDriver,
      pickup: EmergencyLocation(latitude: latitude, longitude: longitude, address: address),
      emergencyType: emergencyType ?? 'Darurat Umum',
      patientNotes: notes,
      searchRadiusKm: 3,
    );
    return _current!;
  }

  @override
  Future<EmergencyRequestModel?> getCurrentRequest() async => _current;

  @override
  Future<EmergencyRequestModel> getRequest(String id) async => _current!;

  @override
  Future<EmergencyRequestModel> widenRadius(String id) async {
    calls.add('radius $id');
    return _current = _search(radiusKm: 5);
  }

  @override
  Future<EmergencyRequestModel> retrySearch(String id) async {
    calls.add('retry $id');
    return _current = _search(radiusKm: 25);
  }

  @override
  Future<EmergencyRequestModel> cancelRequest(String id, {String? reason}) async {
    _current = EmergencyRequestModel(
      id: id,
      requestCode: 'CA-TEST1',
      status: EmergencyRequestStatus.cancelled,
      pickup: const EmergencyLocation(latitude: -6.2088, longitude: 106.8222, address: 'Test'),
    );
    return _current!;
  }
}

const _dummyUser = AuthUser(
  id: 'usr-1',
  fullName: 'Siti Rahmawati',
  roles: ['user'],
);

/// The search map's pulse runs forever, so wait a fixed time instead of
/// pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _pumpShell(
  WidgetTester tester,
  _FakeEmergencyRepository repo,
) async {
  // Wide enough for the test font, whose glyphs are all full squares.
  tester.view.physicalSize = const Size(1800, 3200);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [emergencyRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: UserShell(user: _dummyUser)),
    ),
  );
  await _settle(tester);
}

void main() {
  const dummyUser = AuthUser(
    id: 'usr-1',
    fullName: 'Siti Rahmawati',
    email: 'pasien@cariambulan.id',
    phone: '081234567890',
    roles: ['user'],
  );

  group('Emergency Flow Domain & State Tests', () {
    test('EmergencyRequestModel parses JSON with driver and ambulance', () {
      final json = {
        'id': 'req-99',
        'request_code': 'CA-ABCDEF',
        'status': 'driver_assigned',
        'is_for_self': true,
        'emergency_type': 'cardiac',
        'pickup': {
          'latitude': -6.2088,
          'longitude': 106.8222,
          'address': 'Grand Indonesia',
        },
        'search': {'radius_km': 5, 'is_exhausted': false},
        'assigned_driver': {
          'id': 'drv-1',
          'name': 'Budi Santoso',
          'phone': '081200001199',
          'license_number': 'SIM-123',
        },
        'ambulance': {
          'id': 'amb-1',
          'plate_number': 'B 1199 SGM',
          'ambulance_type': 'ALS',
        },
      };

      final model = EmergencyRequestModel.fromJson(json);

      expect(model.requestCode, 'CA-ABCDEF');
      expect(model.status, EmergencyRequestStatus.driverAssigned);
      expect(model.status.isActiveTrip, isTrue);
      expect(model.assignedDriver?.name, 'Budi Santoso');
      expect(model.ambulance?.plateNumber, 'B 1199 SGM');
    });

    test('EmergencyRequestModel reads the search progress', () {
      final model = EmergencyRequestModel.fromJson({
        'id': 'req-7',
        'code': 'CA-RADIUS',
        'status': 'searching_driver',
        'pickup': {'latitude': -6.2, 'longitude': 106.8, 'address': 'Plaza'},
        'drivers_contacted': 3,
        'search_radius_km': 10,
        'radius_expands_in_seconds': 12,
        'search_exhausted': false,
        'nearby_ambulances': [
          {'latitude': -6.21, 'longitude': 106.81, 'distance_km': 1.4},
        ],
      });

      expect(model.searchRadiusKm, 10);
      expect(model.driversContacted, 3);
      expect(model.radiusExpandsInSeconds, 12);
      expect(model.isExhausted, isFalse);
      expect(model.nearbyAmbulances.single.latitude, -6.21);
    });

    test('EmergencyNotifier triggers SOS and sets active request', () async {
      final fakeRepo = _FakeEmergencyRepository();
      final notifier = EmergencyNotifier(fakeRepo, LocationService());

      expect(notifier.state, isA<EmergencyInitial>());

      await notifier.triggerSOS(emergencyType: 'Jantung', notes: 'Nyeri dada');

      expect(notifier.state, isA<EmergencyActive>());
      final active = notifier.state as EmergencyActive;
      expect(active.request.emergencyType, 'Jantung');
      expect(active.request.status, EmergencyRequestStatus.searchingDriver);

      await notifier.cancelRequest(reason: 'Batal coba');
      expect(notifier.state, isA<EmergencyInitial>());
      notifier.dispose();
    });
  });

  group('UserShell UI Presentation Tests', () {
    testWidgets('Renders SosButton when state is EmergencyInitial', (tester) async {
      final fakeRepo = _FakeEmergencyRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            emergencyRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: UserShell(user: dummyUser),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Halo, Siti Rahmawati'), findsOneWidget);
      expect(find.byType(SosButton), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);
    });

    testWidgets('Search screen widens the radius one step', (tester) async {
      final fakeRepo = _FakeEmergencyRepository();
      fakeRepo._current = const EmergencyRequestModel(
        id: 'req-1',
        requestCode: 'CA-SEARCH',
        status: EmergencyRequestStatus.searchingDriver,
        pickup: EmergencyLocation(latitude: -6.2, longitude: 106.8, address: 'Plaza Indonesia'),
        searchRadiusKm: 3,
        driversContacted: 1,
        emergencyType: 'Jantung',
      );

      await _pumpShell(tester, fakeRepo);

      expect(find.byType(SearchingAmbulanceView), findsOneWidget);
      expect(find.text('Mencari ambulans terdekat...'), findsOneWidget);
      expect(find.text('Driver dihubungi'), findsOneWidget);
      expect(find.text('1 ambulans siaga dalam 3\u00A0km'), findsOneWidget);

      // Only the next step can be tapped.
      await tester.tap(find.bySemanticsLabel('Radius 10\u00A0km'));
      await _settle(tester);
      expect(fakeRepo.calls, isEmpty);

      await tester.tap(find.bySemanticsLabel('Radius 5\u00A0km'));
      await _settle(tester);

      expect(fakeRepo.calls, ['radius req-1']);
      expect(find.text('2 ambulans siaga dalam 5\u00A0km'), findsOneWidget);
    });

    testWidgets('No ambulance found offers 119 and a full retry', (tester) async {
      final fakeRepo = _FakeEmergencyRepository();
      fakeRepo._current = const EmergencyRequestModel(
        id: 'req-1',
        requestCode: 'CA-SEARCH',
        status: EmergencyRequestStatus.searchingDriver,
        pickup: EmergencyLocation(latitude: -6.2, longitude: 106.8, address: 'Plaza Indonesia'),
        searchRadiusKm: 25,
        isExhausted: true,
        driversContacted: 4,
      );

      await _pumpShell(tester, fakeRepo);

      expect(find.text('Belum ada ambulans tersedia'), findsOneWidget);
      expect(find.text('Telepon 119 Sekarang'), findsOneWidget);

      await tester.tap(find.text('Cari Lagi · radius 25\u00A0km'));
      await _settle(tester);

      expect(fakeRepo.calls, ['retry req-1']);
      expect(find.text('Mencari ambulans terdekat...'), findsOneWidget);
    });

    testWidgets('Renders AssignedDriverCard when driver is assigned', (tester) async {
      final fakeRepo = _FakeEmergencyRepository();
      fakeRepo._current = const EmergencyRequestModel(
        id: 'req-2',
        requestCode: 'CA-ASSIGNED',
        status: EmergencyRequestStatus.driverAssigned,
        pickup: EmergencyLocation(latitude: -6.2, longitude: 106.8, address: 'Sudirman Tower'),
        assignedDriver: AssignedDriver(
          id: 'd-1',
          name: 'Budi Santoso',
          phone: '081200001199',
          licenseNumber: 'SIM-31750001',
        ),
        ambulance: AmbulanceInfo(
          id: 'a-1',
          plateNumber: 'B 1199 SGM',
          vehicleModel: 'Toyota HiAce ALS',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            emergencyRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: UserShell(user: dummyUser),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AssignedDriverCard), findsOneWidget);
      expect(find.text('Ambulans Ditugaskan'), findsAtLeastNWidgets(1));
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('B 1199 SGM'), findsOneWidget);
      expect(find.text('Toyota HiAce ALS'), findsOneWidget);
      expect(find.text('HUBUNGI PENGEMUDI'), findsOneWidget);
    });
  });
}
