import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/api_driver_repository.dart';
import '../../data/driver_repository.dart';
import '../../domain/driver_models.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  ref.watch(authProvider.select((auth) => auth.value?.id));
  return ApiDriverRepository(ref.watch(apiClientProvider));
});

class DriverHomeState {
  const DriverHomeState({
    required this.profile,
    this.isUpdating = false,
    this.error,
  });

  final DriverProfile profile;
  final bool isUpdating;
  final String? error;

  DriverHomeState copyWith({
    DriverProfile? profile,
    bool? isUpdating,
    String? error,
  }) {
    return DriverHomeState(
      profile: profile ?? this.profile,
      isUpdating: isUpdating ?? this.isUpdating,
      error: error,
    );
  }
}

final driverHomeProvider =
    AsyncNotifierProvider<DriverHomeNotifier, DriverHomeState>(
  DriverHomeNotifier.new,
);

class DriverHomeNotifier extends AsyncNotifier<DriverHomeState> {
  DriverRepository get _repo => ref.read(driverRepositoryProvider);

  @override
  Future<DriverHomeState> build() async {
    final profile = await _repo.fetchProfile();
    return DriverHomeState(profile: profile);
  }

  Future<void> toggleAvailability({
    double defaultLat = -6.2088,
    double defaultLng = 106.8222,
  }) async {
    final current = state.value;
    if (current == null || current.isUpdating) return;

    final targetOnline = !current.profile.isOnline;
    final targetStatus =
        targetOnline ? DriverAvailability.online : DriverAvailability.offline;

    state = AsyncData(current.copyWith(isUpdating: true, error: null));

    try {
      final updated = await _repo.setAvailability(
        targetStatus,
        latitude: targetOnline ? defaultLat : null,
        longitude: targetOnline ? defaultLng : null,
      );
      state = AsyncData(
        current.copyWith(profile: updated, isUpdating: false, error: null),
      );
    } catch (e) {
      state = AsyncData(
        current.copyWith(
          isUpdating: false,
          error: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }
}

