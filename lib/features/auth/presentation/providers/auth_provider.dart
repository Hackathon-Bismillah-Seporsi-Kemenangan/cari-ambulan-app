import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_log.dart';
import '../../../../core/network/api_providers.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthUser?>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AuthUser?> build() async {
    ref.read(apiClientProvider).onUnauthorized = () {
      if (state.value != null) state = const AsyncData(null);
    };

    final saved = await _repo.savedSession();
    if (saved == null) return _repo.restoreSession();

    // Fast load with background verification
    unawaited(_confirm(saved));
    return saved;
  }

  Future<void> _confirm(AuthUser saved) async {
    try {
      final user = await _repo.restoreSession();
      if (state.value?.id != saved.id) return;
      state = AsyncData(user);
    } catch (e) {
      AppLog.warn('Auth', 'Session verification failed; using saved session', e);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final user = await _repo.login(email, password);
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> register(RegistrationData data) async {
    state = const AsyncLoading();
    try {
      final user = await _repo.register(data);
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }
}

