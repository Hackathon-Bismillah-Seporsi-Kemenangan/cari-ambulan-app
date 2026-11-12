import 'package:cari_ambulan_app/features/emergency/domain/emergency_models.dart';
import 'package:cari_ambulan_app/features/emergency/presentation/widgets/trip_share.dart';
import 'package:flutter_test/flutter_test.dart';

EmergencyRequestModel _request(
  EmergencyRequestStatus status, {
  AmbulanceInfo? ambulance = const AmbulanceInfo(
    plateNumber: 'B 1234 XY',
    latitude: -6.2,
    longitude: 106.8,
  ),
  HospitalInfo? hospital,
}) => EmergencyRequestModel(
  id: 'req-1',
  requestCode: 'CA-1',
  status: status,
  pickup: const EmergencyLocation(
    latitude: -6.21,
    longitude: 106.82,
    address: 'Jl. Sudirman 1',
  ),
  assignedDriver: const AssignedDriver(name: 'Budi'),
  ambulance: ambulance,
  etaMinutes: 6,
  hospital: hospital,
);

void main() {
  test('on the way: pickup, ambulance, ETA, and both map links', () {
    final text = tripShareText(
      _request(EmergencyRequestStatus.enRouteToPickup),
    );
    expect(
      text,
      startsWith(
        'Saya sedang menunggu ambulans CariAmbulan B 1234 XY (driver Budi) '
        'di Jl. Sudirman 1. Perkiraan tiba 6 menit lagi.',
      ),
    );
    expect(text, contains('Lokasi jemput: https://www.google.com/maps/'));
    expect(text, contains('query=-6.21,106.82'));
    expect(text, contains('Posisi ambulans saat ini: '));
    expect(text, contains('query=-6.2,106.8'));
  });

  test('without a plate or a position yet, still reads well', () {
    final text = tripShareText(
      _request(EmergencyRequestStatus.driverAssigned, ambulance: null),
    );
    expect(text, contains('menunggu ambulans CariAmbulan (driver Budi)'));
    expect(text, isNot(contains('Posisi ambulans')));
  });

  test('arrived: no ambulance link, it is at the pickup', () {
    final text = tripShareText(_request(EmergencyRequestStatus.arriveAtPickup));
    expect(
      text,
      'Ambulans CariAmbulan B 1234 XY (driver Budi) sudah tiba di '
      'Jl. Sudirman 1.',
    );
  });

  test('to the hospital: names it and links it', () {
    final text = tripShareText(
      _request(
        EmergencyRequestStatus.enRouteToHospital,
        hospital: const HospitalInfo(
          name: 'RSUD Tarakan',
          latitude: -6.17,
          longitude: 106.81,
        ),
      ),
    );
    expect(text, contains('dibawa ambulans CariAmbulan B 1234 XY'));
    expect(text, contains('ke RSUD Tarakan.'));
    expect(text, contains('Rumah sakit: '));
    expect(text, contains('query=-6.17,106.81'));
    expect(text, contains('Posisi ambulans saat ini: '));
  });
}
