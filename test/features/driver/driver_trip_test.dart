import 'package:cari_ambulan_app/features/driver/data/driver_repository.dart';
import 'package:cari_ambulan_app/features/driver/domain/dispatch_offer_model.dart';
import 'package:cari_ambulan_app/features/driver/domain/driver_models.dart';
import 'package:cari_ambulan_app/features/driver/presentation/providers/driver_home_provider.dart';
import 'package:cari_ambulan_app/features/driver/presentation/widgets/active_trip_card.dart';
import 'package:cari_ambulan_app/features/emergency/domain/emergency_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockTripDriverRepo implements DriverRepository {
  EmergencyRequestModel? _trip;

  _MockTripDriverRepo([this._trip]);

  @override
  Future<DriverProfile> fetchProfile() async => throw UnimplementedError();

  @override
  Future<DriverProfile> setAvailability(DriverAvailability availability, {double? latitude, double? longitude}) async =>
      throw UnimplementedError();

  @override
  Future<void> sendLocation(double latitude, double longitude) async {}

  @override
  Future<DispatchOfferModel?> getCurrentOffer() async => null;

  @override
  Future<EmergencyRequestModel> acceptOffer(int offerId) async => throw UnimplementedError();

  @override
  Future<void> declineOffer(int offerId) async {}

  @override
  Future<EmergencyRequestModel?> getActiveTrip() async => _trip;

  @override
  Future<EmergencyRequestModel> updateTripStatus(String status) async {
    _trip = EmergencyRequestModel(
      id: _trip?.id ?? 'req-1',
      requestCode: _trip?.requestCode ?? 'CA-TRIP1',
      status: EmergencyRequestStatus.fromString(status),
      pickup: _trip?.pickup ?? const EmergencyLocation(latitude: -6.2, longitude: 106.8, address: 'Test Lokasi'),
    );
    return _trip!;
  }
}

void main() {
  const dummyTrip = EmergencyRequestModel(
    id: 'trip-1',
    requestCode: 'CA-RUN1',
    status: EmergencyRequestStatus.driverAssigned,
    pickup: EmergencyLocation(latitude: -6.2088, longitude: 106.8222, address: 'Jl. Sudirman No. 10'),
    emergencyType: 'Jantung',
    patientNotes: 'Nyeri dada',
  );

  group('DriverTrip State & Workflow Tests', () {
    testWidgets('ActiveTripCard renders active trip details and advances stage', (tester) async {
      final mockRepo = _MockTripDriverRepo(dummyTrip);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            driverRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ActiveTripCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TUGAS AKTIF'), findsOneWidget);
      expect(find.text('Jl. Sudirman No. 10'), findsOneWidget);
      expect(find.text('MULAI MELUNCUR KE PASIEN'), findsOneWidget);

      // Tap to advance to en_route_to_pickup
      await tester.tap(find.text('MULAI MELUNCUR KE PASIEN'));
      await tester.pumpAndSettle();

      expect(find.text('TIBA DI LOKASI JEMPUT'), findsOneWidget);
    });
  });
}
