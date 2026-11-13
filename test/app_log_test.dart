import 'dart:convert';

import 'package:cari_ambulan/core/logging/app_log.dart';
import 'package:cari_ambulan/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final lines = <String>[];
  setUp(() {
    lines.clear();
    AppLog.output = lines.add;
  });

  test('one aligned line per log', () {
    AppLog.warn('Route', 'router.project-osrm.org failed', 'Timeout');
    expect(lines.single, contains('! WARN  Route'));
    expect(lines.single, endsWith('router.project-osrm.org failed: Timeout'));
  });

  test('a poll that returns the same thing is logged once', () async {
    var status = 'searching_driver';
    final api = ApiClient(
      baseUrl: 'http://api.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': {'status': status},
          }),
          200,
        ),
      ),
    );

    await api.get('emergency-requests/current');
    await api.get('emergency-requests/current');
    await api.get('emergency-requests/current');
    status = 'driver_assigned';
    await api.get('emergency-requests/current');

    expect(lines, hasLength(2));
    expect(lines.first, contains('GET emergency-requests/current → 200'));
    expect(lines.first, contains('status=searching_driver'));
    expect(lines.last, contains('status=driver_assigned'));
    expect(lines.last, contains('(after 2 unchanged polls)'));
  });

  test('failed calls are logged with the server message', () async {
    final api = ApiClient(
      baseUrl: 'http://api.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Sudah diambil driver lain.'}),
          409,
        ),
      ),
    );

    await expectLater(
      api.post('driver/requests/1/accept'),
      throwsA(isA<ApiException>()),
    );
    expect(lines.single, contains('WARN'));
    expect(lines.single, contains('POST driver/requests/1/accept → 409'));
    expect(lines.single, contains('Sudah diambil driver lain.'));
  });
}
