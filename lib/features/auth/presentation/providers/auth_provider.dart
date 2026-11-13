import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_log.dart';
import '../../../../core/network/api_providers.dart';
import '../../../../core/notifications/fcm_service.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

/// The signed-in user, or null when signed out. Drives the app's root
/// screen (login vs. driver app).
final authProvider = AsyncNotifierProvider<AuthNotifier, AuthUser?>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AuthUser?> build() async {
    // A revoked or expired token anywhere in the app signs the driver out.
    ref.read(apiClientProvider).onUnauthorized = () {
      if (state.value != null) state = const AsyncData(null);
    };
    final saved = await _repo.savedSession();
    if (saved == null) return _repo.restoreSession();
    // Open the app now; a slow server only delays the check.
    unawaited(_confirm(saved));
    return saved;
  }

  /// Signs out if the saved session was revoked, else refreshes the
  /// account. Offline, the saved account stays.
  Future<void> _confirm(AuthUser saved) async {
    try {
      final user = await _repo.restoreSession();
      // Signed out or in as someone else meanwhile.
      if (state.value?.id != saved.id) return;
      state = AsyncData(user);
      _syncFcmToken();
    } catch (e) {
      AppLog.warn('Auth', 'Session check failed; using the saved one', e);
    }
  }

  /// Throws [ApiException] with a displayable message on failure.
  Future<void> login(String email, String password) async {
    final user = await _repo.login(email, password);
    state = AsyncData(user);
    _syncFcmToken();
  }

  Future<void> register(RegistrationData data) async {
    final user = await _repo.register(data);
    state = AsyncData(user);
    _syncFcmToken();
  }

  void _syncFcmToken() {
    FcmService.syncTokenWithBackend(ref.read(apiClientProvider)).ignore();
  }

  /// After the account was edited (e.g. Profil's name and phone).
  void updateUser(AuthUser user) {
    state = AsyncData(user);
    unawaited(_repo.saveUser(user));
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }
}
