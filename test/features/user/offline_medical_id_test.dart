import 'package:cari_ambulan_app/core/network/api_client.dart';
import 'package:cari_ambulan_app/features/user/data/medical_repository.dart';
import 'package:cari_ambulan_app/features/user/data/medical_store.dart';
import 'package:cari_ambulan_app/features/user/domain/medical_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The server, reachable or not.
class _Server implements MedicalRepository {
  MedicalProfile stored = const MedicalProfile(bloodType: 'O+');
  bool online = true;

  /// Thrown instead of answering, e.g. a validation error.
  ApiException? error;
  final saves = <MedicalProfile>[];

  void _check() {
    if (!online) {
      throw const ApiException('Tidak dapat terhubung ke server.');
    }
    if (error case final error?) throw error;
  }

  @override
  Future<MedicalProfile> fetch() async {
    _check();
    return stored;
  }

  @override
  Future<MedicalProfile> save(MedicalProfile profile) async {
    _check();
    saves.add(profile);
    return stored = profile;
  }

  @override
  Future<bool> hasPendingSync() async => false;
}

void main() {
  late _Server server;
  late OfflineMedicalRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = _Server();
    repo = OfflineMedicalRepository(server, const MedicalStore('u-1'));
  });

  test('offline, the last Medical ID loaded is shown', () async {
    expect((await repo.fetch()).bloodType, 'O+');

    server.online = false;
    expect((await repo.fetch()).bloodType, 'O+');
    expect(await repo.hasPendingSync(), isFalse);
  });

  test('offline with nothing saved yet, loading fails as before', () async {
    server.online = false;
    await expectLater(repo.fetch(), throwsA(isA<ApiException>()));
  });

  test('an offline edit is kept, shown, and sent once online', () async {
    await repo.fetch();
    server.online = false;

    await expectLater(
      repo.save(const MedicalProfile(bloodType: 'A-')),
      throwsA(isA<MedicalSavedOffline>()),
    );
    expect(await repo.hasPendingSync(), isTrue);
    expect((await repo.fetch()).bloodType, 'A-');

    // Online again: the edit wins over the server's older copy.
    server.online = true;
    expect((await repo.fetch()).bloodType, 'A-');
    expect(server.stored.bloodType, 'A-');
    expect(await repo.hasPendingSync(), isFalse);
  });

  test('a validation error is shown, not saved for later', () async {
    server.error = const ApiException(
      'Golongan darah tidak valid.',
      statusCode: 422,
    );
    await expectLater(
      repo.save(const MedicalProfile(bloodType: 'X')),
      throwsA(isA<ApiException>()),
    );
    expect(await repo.hasPendingSync(), isFalse);
  });

  test('signing out clears Medical IDs from the phone', () async {
    await repo.fetch();
    await MedicalStore.clearAll();

    server.online = false;
    await expectLater(repo.fetch(), throwsA(isA<ApiException>()));
  });

  test('each account has its own saved Medical ID', () async {
    await repo.fetch();
    server.online = false;
    final other = OfflineMedicalRepository(server, const MedicalStore('u-2'));
    await expectLater(other.fetch(), throwsA(isA<ApiException>()));
  });
}
