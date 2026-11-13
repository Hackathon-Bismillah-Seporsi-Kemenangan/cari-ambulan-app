import 'package:cari_ambulan/features/user/domain/user_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const where = LatLng(-6.2, 106.8);

  test('a fresh position is not silent', () {
    const trip = TripInfo(ambulanceLocation: where, locationAgeSeconds: 5);
    expect(trip.driverSilent, isFalse);
  });

  test('a position older than the threshold means the driver went quiet', () {
    const trip = TripInfo(ambulanceLocation: where, locationAgeSeconds: 240);
    expect(trip.driverSilent, isTrue);
  });

  test('no position at all is not reported as silent', () {
    const trip = TripInfo(locationAgeSeconds: 600);
    expect(trip.driverSilent, isFalse);
  });

  test('an older server without the age field keeps working', () {
    const trip = TripInfo(ambulanceLocation: where);
    expect(trip.driverSilent, isFalse);
  });
}
