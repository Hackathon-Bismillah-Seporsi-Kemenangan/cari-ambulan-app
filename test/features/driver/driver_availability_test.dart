import 'package:cari_ambulan_app/features/driver/data/driver_repository.dart';
import 'package:cari_ambulan_app/features/driver/domain/dispatch_offer_model.dart';
import 'package:cari_ambulan_app/features/driver/domain/driver_models.dart';
import 'package:cari_ambulan_app/features/driver/presentation/providers/driver_home_provider.dart';
import 'package:cari_ambulan_app/features/driver/presentation/widgets/availability_card.dart';
import 'package:cari_ambulan_app/features/emergency/domain/emergency_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockDriverRepository implements DriverRepository {
  _MockDriverRepository(this._profile);

  DriverProfile _profile;

  @override
  Future<DriverProfile> fetchProfile() async => _profile;

  @override
  Future<DriverProfile> setAvailability(
    DriverAvailability availability, {
    double? latitude,
    double? longitude,
  }) async {
    _profile = _profile.copyWith(
      availabilityStatus: availability,
      currentLatitude: latitude,
      currentLongitude: longitude,
    );
    return _profile;
  }

  @override
  Future<void> sendLocation(double latitude, double longitude) async {
    _profile = _profile.copyWith(
      currentLatitude: latitude,
      currentLongitude: longitude,
    );
  }

  @override
  Future<DispatchOfferModel?> getCurrentOffer() async => null;

  @override
  Future<EmergencyRequestModel> acceptOffer(int offerId) async => throw UnimplementedError();

  @override
  Future<void> declineOffer(int offerId) async {}
}

void main() {
  group('Driver Domain Model Tests', () {
    test('DriverProfile.fromJson parses valid JSON data correctly', () {
      final profile = DriverProfile.fromJson({
        'id': 'drv-1',
        'name': 'Budi Santoso',
        'phone': '081200001199',
        'license_number': 'SIM-31750001',
        'availability_status': 'offline',
        'vehicle': {
          'plate_number': 'B 1199 SGM',
          'vehicle_type': 'Ambulans ALS',
        },
        'hospital': {
          'id': 'hosp-1',
          'name': 'RS Medika',
        },
      });

      expect(profile.id, 'drv-1');
      expect(profile.name, 'Budi Santoso');
      expect(profile.vehiclePlate, 'B 1199 SGM');
      expect(profile.hospitalName, 'RS Medika');
      expect(profile.isOffline, isTrue);
      expect(profile.isOnline, isFalse);
    });
  });

  group('AvailabilityCard Widget Tests', () {
    testWidgets('displays OFFLINE status and vehicle details', (tester) async {
      const profile = DriverProfile(
        id: 'drv-1',
        name: 'Budi Santoso',
        vehiclePlate: 'B 1199 SGM',
        vehicleType: 'Ambulans ALS',
        hospitalName: 'RS Medika',
        availabilityStatus: DriverAvailability.offline,
      );

      var toggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvailabilityCard(
              profile: profile,
              isUpdating: false,
              onToggle: () => toggled = true,
            ),
          ),
        ),
      );

      expect(find.text('TIDAK AKTIF (OFFLINE)'), findsOneWidget);
      expect(find.text('B 1199 SGM · Ambulans ALS'), findsOneWidget);
      expect(find.text('RS Medika'), findsOneWidget);

      // Tap the switch
      await tester.tap(find.byType(Switch));
      expect(toggled, isTrue);
    });

    testWidgets('displays ONLINE status when active', (tester) async {
      const profile = DriverProfile(
        id: 'drv-1',
        name: 'Budi Santoso',
        vehiclePlate: 'B 1199 SGM',
        vehicleType: 'Ambulans ALS',
        hospitalName: 'RS Medika',
        availabilityStatus: DriverAvailability.online,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvailabilityCard(
              profile: profile,
              isUpdating: false,
              onToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('SIAP BERTUGAS (ONLINE)'), findsOneWidget);
    });
  });

  group('DriverHomeNotifier State Tests', () {
    test('toggleAvailability updates status from offline to online', () async {
      const initialProfile = DriverProfile(
        id: 'drv-1',
        name: 'Budi Santoso',
        vehiclePlate: 'B 1199 SGM',
        vehicleType: 'Ambulans ALS',
        availabilityStatus: DriverAvailability.offline,
      );

      final mockRepo = _MockDriverRepository(initialProfile);
      final container = ProviderContainer(
        overrides: [
          driverRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      addTearDown(container.dispose);

      // Initial read
      final state = await container.read(driverHomeProvider.future);
      expect(state.profile.isOffline, isTrue);

      // Toggle to online
      await container.read(driverHomeProvider.notifier).toggleAvailability();
      final updatedState = container.read(driverHomeProvider).value!;
      expect(updatedState.profile.isOnline, isTrue);
    });
  });
}

