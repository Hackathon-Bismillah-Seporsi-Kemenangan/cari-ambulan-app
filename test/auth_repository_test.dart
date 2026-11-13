import 'dart:convert';

import 'package:cari_ambulan/core/constants/user_role.dart';
import 'package:cari_ambulan/core/network/api_client.dart';
import 'package:cari_ambulan/features/auth/data/auth_repository.dart';
import 'package:cari_ambulan/features/auth/domain/auth_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _storage = FlutterSecureStorage();

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

RegistrationData _registration(UserRole role) => RegistrationData(
  fullName: ' Ayu Pratama ',
  email: ' ayu@example.com ',
  phone: ' 081234567890 ',
  password: ' MedicGo123! ',
  passwordConfirmation: ' MedicGo123! ',
  role: role,
  licenseNumber: ' SIM-123456 ',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'a first launch has no session and makes no authenticated request',
    () async {
      final api = ApiClient(
        client: MockClient((_) async {
          fail('No request should be made without a saved token');
        }),
      );

      expect(await AuthRepository(api).restoreSession(), isNull);
    },
  );

  for (final (role, apiRole) in [
    (UserRole.patient, 'user'),
    (UserRole.driver, 'driver'),
  ]) {
    test('registers $apiRole and restores the saved bearer session', () async {
      final requests = <http.Request>[];
      final account = {
        'id': 'account-1',
        'full_name': 'Ayu Pratama',
        'email': 'ayu@example.com',
        'phone': '081234567890',
        'roles': [apiRole],
      };
      final client = MockClient((request) async {
        requests.add(request);
        return request.method == 'POST'
            ? _json({'token': 'session-token', 'user': account}, 201)
            : _json({'data': account});
      });
      final api = ApiClient(client: client, baseUrl: 'http://api.test');

      final user = await AuthRepository(api).register(_registration(role));

      expect(requests.single.url.path, '/api/v1/auth/register');
      expect(jsonDecode(requests.single.body), {
        'full_name': 'Ayu Pratama',
        'email': 'ayu@example.com',
        'phone': '081234567890',
        'password': ' MedicGo123! ',
        'password_confirmation': ' MedicGo123! ',
        'role': apiRole,
        if (role.isDriver) 'license_number': 'SIM-123456',
        'device_name': 'medicgo-app',
      });
      expect(user.roles, [apiRole]);
      expect(await _storage.read(key: 'auth_token'), 'session-token');

      final restartedApi = ApiClient(
        client: client,
        baseUrl: 'http://api.test',
      );
      final restored = await AuthRepository(restartedApi).restoreSession();
      expect(restored?.id, 'account-1');
      expect(requests.last.url.path, '/api/v1/auth/me');
      expect(requests.last.headers['Authorization'], 'Bearer session-token');
    });
  }

  test('registration validation errors never establish a session', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => _json({
          'errors': {
            'email': ['Email ini sudah terdaftar. Silakan masuk.'],
          },
        }, 422),
      ),
    );

    await expectLater(
      AuthRepository(api).register(_registration(UserRole.patient)),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'status', 422)
            .having(
              (error) => error.message,
              'message',
              'Email ini sudah terdaftar. Silakan masuk.',
            ),
      ),
    );
    expect(api.token, isNull);
    expect(await _storage.read(key: 'auth_token'), isNull);
  });

  test('an expired restored session clears the token', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'expired'});
    final api = ApiClient(
      client: MockClient(
        (_) async => _json({'message': 'Unauthenticated.'}, 401),
      ),
    );

    expect(await AuthRepository(api).restoreSession(), isNull);
    expect(api.token, isNull);
    expect(await _storage.read(key: 'auth_token'), isNull);
  });

  test('logout clears the bearer token and secure storage', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'session-token'});
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/logout');
        expect(request.headers['Authorization'], 'Bearer session-token');
        return http.Response('', 204);
      }),
    )..token = 'session-token';

    await AuthRepository(api).logout();

    expect(api.token, isNull);
    expect(await _storage.read(key: 'auth_token'), isNull);
  });
}
