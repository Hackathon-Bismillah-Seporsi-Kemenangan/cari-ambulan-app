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

    testWidgets('Renders SearchingAmbulanceView when searching driver', (tester) async {
      final fakeRepo = _FakeEmergencyRepository();
      fakeRepo._current = const EmergencyRequestModel(
        id: 'req-1',
        requestCode: 'CA-SEARCH',
        status: EmergencyRequestStatus.searchingDriver,
        pickup: EmergencyLocation(latitude: -6.2, longitude: 106.8, address: 'Plaza Indonesia'),
        searchRadiusKm: 3,
        emergencyType: 'Jantung',
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

      expect(find.byType(SearchingAmbulanceView), findsOneWidget);
      expect(find.text('Mencari Ambulans Terdekat...'), findsOneWidget);
      expect(find.text('Radius pencarian: 3 km'), findsOneWidget);
      expect(find.text('Plaza Indonesia'), findsOneWidget);
      expect(find.text('Batalkan Panggilan'), findsOneWidget);
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
      expect(find.text('Ambulans Ditugaskan'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('B 1199 SGM'), findsOneWidget);
      expect(find.text('Toyota HiAce ALS'), findsOneWidget);
      expect(find.text('HUBUNGI PENGEMUDI'), findsOneWidget);
    });
  });
}
