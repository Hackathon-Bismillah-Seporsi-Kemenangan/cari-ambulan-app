import 'dart:convert';

import 'package:cari_ambulan_app/core/network/api_client.dart';
import 'package:cari_ambulan_app/features/emergency/data/api_emergency_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A request as the server's `EmergencySearchResource` sends it.
Map<String, dynamic> _search(double radiusKm) => {
      'id': 'req-9',
      'code': 'CA-SRCH01',
      'status': 'searching_driver',
      'pickup': {'latitude': -6.2, 'longitude': 106.8, 'address': 'Plaza'},
      'drivers_contacted': 2,
      'search_radius_km': radiusKm,
      'radius_expands_in_seconds': 20,
      'search_exhausted': false,
      'nearby_ambulances': const [],
    };

void main() {
  late List<String> calls;

  ApiEmergencyRepository repoReturning(double radiusKm) {
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      return http.Response(jsonEncode({'data': _search(radiusKm)}), 200);
    });
    return ApiEmergencyRepository(
      ApiClient(client: client, baseUrl: 'http://test'),
    );
  }

  setUp(() => calls = []);

  test('polls the request by id', () async {
    final request = await repoReturning(3).getRequest('req-9');

    expect(calls, ['GET /api/v1/emergency-requests/req-9']);
    expect(request.driversContacted, 2);
  });

  test('widens the radius and retries the search', () async {
    final widened = await repoReturning(5).widenRadius('req-9');
    final retried = await repoReturning(25).retrySearch('req-9');

    expect(calls, [
      'POST /api/v1/emergency-requests/req-9/radius',
      'POST /api/v1/emergency-requests/req-9/retry',
    ]);
    expect(widened.searchRadiusKm, 5);
    expect(retried.searchRadiusKm, 25);
  });
}
