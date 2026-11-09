import 'package:cari_ambulan_app/core/map/route_trim.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  // An L-shaped route in Jember: east along one street, then north.
  const route = [
    LatLng(-8.1700, 113.7000),
    LatLng(-8.1700, 113.7010),
    LatLng(-8.1700, 113.7020),
    LatLng(-8.1690, 113.7020),
    LatLng(-8.1680, 113.7020),
  ];

  test('starts at the ambulance and drops the part already driven', () {
    // Halfway along the second segment.
    const ambulance = LatLng(-8.1700, 113.7015);
    expect(routeAhead(route, ambulance), [
      ambulance,
      const LatLng(-8.1700, 113.7020),
      const LatLng(-8.1690, 113.7020),
      const LatLng(-8.1680, 113.7020),
    ]);
  });

  test('matches a slightly off-road GPS fix to the nearest street', () {
    // A few meters north of the first street, past the corner's x.
    const ambulance = LatLng(-8.16998, 113.7005);
    final ahead = routeAhead(route, ambulance);
    expect(ahead.first, ambulance);
    expect(ahead.skip(1), route.skip(1));
  });

  test('after the corner only the northern leg is left', () {
    const ambulance = LatLng(-8.1685, 113.7020);
    expect(routeAhead(route, ambulance), [
      ambulance,
      const LatLng(-8.1680, 113.7020),
    ]);
  });

  test('keeps the whole route before the ambulance has moved', () {
    expect(routeAhead(route, route.first), [route.first, ...route.skip(1)]);
  });

  test('leaves routes too short to draw alone', () {
    expect(routeAhead(const [], const LatLng(-8.17, 113.7)), isEmpty);
  });
}
