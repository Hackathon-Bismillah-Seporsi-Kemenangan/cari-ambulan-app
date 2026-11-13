import 'dart:async';
import 'dart:convert';

import 'package:cari_ambulan/core/network/api_client.dart';
import 'package:cari_ambulan/core/network/api_providers.dart';
import 'package:cari_ambulan/features/auth/data/auth_repository.dart';
import 'package:cari_ambulan/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _storage = FlutterSecureStorage();

const _user = {
  'id': 'user-1',
  'full_name': 'Siti Rahmawati',
  'email': 'pasien@cariambulan.id',
  'phone': null,
  'roles': ['user'],
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// The app's auth state on a server that answers `auth/me` with [answer].
ProviderContainer _app(Future<http.Response> Function() answer) {
  final api = ApiClient(
    client: MockClient((_) => answer()),
    baseUrl: 'http://api.test',
  );
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      authRepositoryProvider.overrideWithValue(AuthRepository(api)),
    ],
  );
  addTearDown(container.dispose);
  container.listen(authProvider, (_, _) {});
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a saved session opens before the server answers', () async {
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'session-token',
      'auth_user': jsonEncode(_user),
    });
    final server = Completer<http.Response>();
    final app = _app(() => server.future);

    expect((await app.read(authProvider.future))?.fullName, 'Siti Rahmawati');

    // The server then says the session was revoked: signed out.
    server.complete(_json({'message': 'Unauthenticated.'}, 401));
    await pumpEventQueue();
    expect(app.read(authProvider).value, isNull);
    expect(await _storage.read(key: 'auth_user'), isNull);
  });

  test('offline, the saved session stays signed in', () async {
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'session-token',
      'auth_user': jsonEncode(_user),
    });
    final app = _app(() async => throw http.ClientException('offline'));

    expect((await app.read(authProvider.future))?.id, 'user-1');
    await pumpEventQueue();
    expect(app.read(authProvider).value?.id, 'user-1');
  });

  test('the server answer refreshes the saved account', () async {
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'session-token',
      'auth_user': jsonEncode(_user),
    });
    final app = _app(
      () async => _json({
        'data': {..._user, 'full_name': 'Siti R.'},
      }),
    );

    await app.read(authProvider.future);
    await pumpEventQueue();
    expect(app.read(authProvider).value?.fullName, 'Siti R.');
    expect(await _storage.read(key: 'auth_user'), contains('Siti R.'));
  });

  test('a token from an older app version waits for the server', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'session-token'});
    final app = _app(() async => _json({'data': _user}));

    expect((await app.read(authProvider.future))?.id, 'user-1');
    // Saved for the next start.
    expect(await _storage.read(key: 'auth_user'), contains('user-1'));
  });
}
