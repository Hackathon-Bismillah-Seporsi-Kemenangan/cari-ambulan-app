import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_log.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_providers.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../domain/medical_profile.dart';
import 'medical_store.dart';

final medicalRepositoryProvider = Provider<MedicalRepository>((ref) {
  final api = ApiMedicalRepository(ref.watch(apiClientProvider));
  final userId = ref.watch(authProvider.select((auth) => auth.value?.id));
  return userId == null
      ? api
      : OfflineMedicalRepository(api, MedicalStore(userId));
});

abstract class MedicalRepository {
  /// The user's Medical ID; [MedicalProfile.empty] before it is filled in.
  Future<MedicalProfile> fetch();

  /// Creates or replaces the Medical ID. Throws [MedicalSavedOffline] when
  /// it was kept on the phone to send later.
  Future<MedicalProfile> save(MedicalProfile profile);

  /// An edit made offline hasn't reached the server yet.
  Future<bool> hasPendingSync();
}

/// The server couldn't be reached: the Medical ID is saved on the phone and
/// sent on the next load.
class MedicalSavedOffline implements Exception {
  const MedicalSavedOffline();
}

class ApiMedicalRepository implements MedicalRepository {
  const ApiMedicalRepository(this._client);

  final ApiClient _client;

  @override
  Future<MedicalProfile> fetch() async {
    final json = await _client.get('me/medical-profile');
    final data = json?['data'] as Map<String, dynamic>?;
    return data == null ? MedicalProfile.empty : MedicalProfile.fromJson(data);
  }

  @override
  Future<MedicalProfile> save(MedicalProfile profile) async {
    final json = await _client.put('me/medical-profile', profile.toJson());
    final data = json?['data'] as Map<String, dynamic>?;
    return data == null ? profile : MedicalProfile.fromJson(data);
  }

  @override
  Future<bool> hasPendingSync() async => false;
}

/// Keeps the Medical ID on the phone: shown without a connection (when it
/// matters most), and edits made offline are sent once the server answers.
class OfflineMedicalRepository implements MedicalRepository {
  const OfflineMedicalRepository(this._remote, this._store);

  final MedicalRepository _remote;
  final MedicalStore _store;

  /// No connection or a server error; a 4xx is a real answer.
  static bool _unreachable(ApiException e) =>
      e.statusCode == null || e.statusCode! >= 500;

  @override
  Future<MedicalProfile> fetch() async {
    final local = await _store.read();

    // An offline edit goes first, or the server's older copy would win.
    if (local != null && local.pending) {
      try {
        final saved = await _remote.save(local.profile);
        await _store.write(saved, pending: false);
        return saved;
      } on ApiException catch (e) {
        if (_unreachable(e)) return local.profile;
        AppLog.warn('MEDICAL', 'Server rejected the offline edit', e);
      }
    }

    try {
      final profile = await _remote.fetch();
      await _store.write(profile, pending: false);
      return profile;
    } on ApiException catch (e) {
      if (local != null && _unreachable(e)) return local.profile;
      rethrow;
    }
  }

  @override
  Future<MedicalProfile> save(MedicalProfile profile) async {
    try {
      final saved = await _remote.save(profile);
      await _store.write(saved, pending: false);
      return saved;
    } on ApiException catch (e) {
      if (!_unreachable(e)) rethrow;
      await _store.write(profile, pending: true);
      throw const MedicalSavedOffline();
    }
  }

  @override
  Future<bool> hasPendingSync() async =>
      (await _store.read())?.pending ?? false;
}
