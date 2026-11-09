import 'dart:convert';

import 'package:cari_ambulan_app/features/driver/data/routing_repository.dart';
import 'package:cari_ambulan_app/features/driver/domain/route_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

const _from = LatLng(-6.2088, 106.8222);
const _to = LatLng(-6.2245, 106.8125);

Map<String, dynamic> _step(
  String type,
  String? modifier,
  String name,
  double distance,
) => {
  'name': name,
  'distance': distance,
  'maneuver': {
    'type': type,
    'modifier': ?modifier,
    'location': [106.82, -6.21],
  },
};

void main() {
  test('parses an OSRM route into steps and instructions', () async {
    final client = MockClient((request) async {
      expect(request.url.path, contains('106.8222,-6.2088;106.8125,-6.2245'));
      return http.Response(
        jsonEncode({
          'code': 'Ok',
          'routes': [
            {
              'distance': 1800.0,
              'duration': 300.0,
              'geometry': {
                'coordinates': [
                  [106.8222, -6.2088],
                  [106.8125, -6.2245],
                ],
              },
              'legs': [
                {
                  'steps': [
                    _step('depart', null, '', 300),
                    _step('turn', 'right', 'Jl. Thamrin', 1500),
                    _step('arrive', 'left', '', 0),
                  ],
                },
              ],
            },
          ],
        }),
        200,
      );
    });

    final route = await OsrmRoutingRepository(
      client: client,
    ).fetchRoute(_from, _to);

    expect(route.isEstimate, isFalse);
    expect(route.points, [_from, _to]);
    expect(route.duration, const Duration(minutes: 5));
    expect(route.distanceToNextManeuver, 300);
    expect(route.nextManeuver?.maneuver, Maneuver.right);
    expect(route.nextManeuver?.instruction, 'Belok kanan ke Jl. Thamrin');
  });

  test('tries the backup server before a straight line', () async {
    final hosts = <String>[];
    final client = MockClient((request) async {
      hosts.add(request.url.host);
      if (hosts.length == 1) return http.Response('busy', 429);
      return http.Response(
        jsonEncode({
          'code': 'Ok',
          'routes': [
            {
              'distance': 1800.0,
              'duration': 300.0,
              'geometry': {
                'coordinates': [
                  [106.8222, -6.2088],
                  [106.8170, -6.2150],
                  [106.8125, -6.2245],
                ],
              },
              'legs': [
                {
                  'steps': [
                    _step('depart', null, '', 1800),
                    _step('arrive', null, '', 0),
                  ],
                },
              ],
            },
          ],
        }),
        200,
      );
    });

    final route = await OsrmRoutingRepository(
      client: client,
    ).fetchRoute(_from, _to);

    expect(hosts, ['router.project-osrm.org', 'routing.openstreetmap.de']);
    expect(route.isEstimate, isFalse);
    expect(route.points, hasLength(3));
  });

  test('falls back to a straight line when routing fails', () async {
    final client = MockClient((_) async => http.Response('down', 503));

    final route = await OsrmRoutingRepository(
      client: client,
    ).fetchRoute(_from, _to);

    expect(route.isEstimate, isTrue);
    expect(route.points, [_from, _to]);
    expect(route.distanceMeters, greaterThan(1000));
  });
}
