import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cari_ambulan/core/network/api_client.dart';

ApiClient _api(MockClient c) => ApiClient(client: c, baseUrl: 'http://api.test');

void main() {
  test('a GET that fails once is retried and succeeds', () async {
    var calls = 0;
    final api = _api(
      MockClient((_) async {
        calls++;
        if (calls == 1) throw http.ClientException('connection reset');
        return http.Response(jsonEncode({'data': {'status': 'searching'}}), 200);
      }),
    );

    final json = await api.get('emergency-requests/1');

    expect(calls, 2);
    expect((json!['data'] as Map)['status'], 'searching');
  });

  test('a GET answered with 502 by a proxy is retried', () async {
    var calls = 0;
    final api = _api(
      MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('Bad Gateway', 502)
            : http.Response(jsonEncode({'data': null}), 200);
      }),
    );

    await api.get('calls/incoming');

    expect(calls, 2);
  });

  test('a POST is never retried (it could create twice)', () async {
    var calls = 0;
    final api = _api(
      MockClient((_) async {
        calls++;
        throw http.ClientException('connection reset');
      }),
    );

    await expectLater(
      api.post('emergency-requests', {'x': 1}),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
  });

  test('an HTML page from a captive portal becomes an ApiException', () async {
    final api = _api(
      MockClient((_) async => http.Response('<html>Login Wi-Fi</html>', 200)),
    );

    await expectLater(
      api.get('auth/me'),
      throwsA(
        isA<ApiException>().having(
          (ApiException e) => e.message,
          'message',
          contains('memblokir'),
        ),
      ),
    );
  });

  test('a 500 with an HTML body still reports a server problem', () async {
    final api = _api(
      MockClient((_) async => http.Response('<h1>Error</h1>', 500)),
    );

    await expectLater(
      api.post('x'),
      throwsA(
        isA<ApiException>()
            .having((ApiException e) => e.statusCode, 'statusCode', 500),
      ),
    );
  });
}
