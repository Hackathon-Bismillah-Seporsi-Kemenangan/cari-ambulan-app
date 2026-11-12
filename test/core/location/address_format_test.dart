import 'package:cari_ambulan_app/core/location/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';

void main() {
  test('street, number and area', () {
    expect(
      LocationService.formatPlacemark(
        Placemark(
          thoroughfare: 'Jalan Kenanga',
          subThoroughfare: '5',
          subLocality: 'Menteng',
          locality: 'Jakarta Pusat',
        ),
      ),
      'Jalan Kenanga No. 5, Menteng',
    );
  });

  test('a number already written as "No.39" is kept', () {
    expect(
      LocationService.formatPlacemark(
        Placemark(thoroughfare: 'Jl. Melati', subThoroughfare: 'No.39'),
      ),
      'Jl. Melati No.39',
    );
  });

  test('a plus code is not an address; the area is used instead', () {
    expect(
      LocationService.formatPlacemark(
        Placemark(street: '6RQ8+2X', locality: 'Bogor'),
      ),
      'Bogor',
    );
  });

  test('nothing known gives null, so coordinates are used', () {
    expect(LocationService.formatPlacemark(Placemark()), isNull);
    expect(
      LocationService.coordinatesLabel(-6.2, 106.816666),
      'Titik GPS -6.20000, 106.81667',
    );
  });
}
