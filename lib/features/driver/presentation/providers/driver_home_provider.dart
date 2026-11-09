import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/location_service.dart';
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
    this.lastBeaconLatitude,
    this.lastBeaconLongitude,
  });

  final DriverProfile profile;
  final bool isUpdating;
  final String? error;
  final double? lastBeaconLatitude;
  final double? lastBeaconLongitude;

  DriverHomeState copyWith({
    DriverProfile? profile,
    bool? isUpdating,
    String? error,
    double? lastBeaconLatitude,
    double? lastBeaconLongitude,
  }) {
    return DriverHomeState(
      profile: profile ?? this.profile,
      isUpdating: isUpdating ?? this.isUpdating,
      error: error,
      lastBeaconLatitude: lastBeaconLatitude ?? this.lastBeaconLatitude,
      lastBeaconLongitude: lastBeaconLongitude ?? this.lastBeaconLongitude,
    );
  }
}

final driverHomeProvider =
    AsyncNotifierProvider<DriverHomeNotifier, DriverHomeState>(
  DriverHomeNotifier.new,
);

class DriverHomeNotifier extends AsyncNotifier<DriverHomeState> {
  DriverRepository get _repo => ref.read(driverRepositoryProvider);
  LocationService get _location => ref.read(locationServiceProvider);

  Timer? _beaconTimer;
  bool _isBeaconing = false;

  /// Enough for dispatch to find an available driver.
  static const _onlineBeaconInterval = Duration(seconds: 10);

  /// During a trip the patient follows the ambulance on a map, and the
  /// server picks the hospital from this position, so it goes out more often.
  static const _tripBeaconInterval = Duration(seconds: 3);

  @override
  Future<DriverHomeState> build() async {
    ref.onDispose(() {
      _beaconTimer?.cancel();
    });

    final profile = await _repo.fetchProfile();

    if (!profile.isOffline) {
      _startLocationBeacon(
        profile.isBusy ? _tripBeaconInterval : _onlineBeaconInterval,
      );
    }

    return DriverHomeState(
      profile: profile,
      lastBeaconLatitude: profile.currentLatitude,
      lastBeaconLongitude: profile.currentLongitude,
    );
  }

  void _startLocationBeacon(Duration interval) {
    _beaconTimer?.cancel();
    _beaconTimer = Timer.periodic(interval, (_) async {
      final current = state.value;
      if (current == null || current.profile.isOffline || _isBeaconing) return;

      // A GPS fix can take longer than the 3 s trip interval.
      _isBeaconing = true;
      try {
        final coords = await _location.getCoordinates();
        await _repo.sendLocation(coords.latitude, coords.longitude);
        state = AsyncData(
          current.copyWith(
            lastBeaconLatitude: coords.latitude,
            lastBeaconLongitude: coords.longitude,
          ),
        );
      } catch (_) {
        // Beacon failure ignored for next retry
      } finally {
        _isBeaconing = false;
      }
    });
  }

  void _stopLocationBeacon() {
    _beaconTimer?.cancel();
    _beaconTimer = null;
  }

  Future<void> toggleAvailability() async {
    final current = state.value;
    if (current == null || current.isUpdating) return;

    final targetOnline = !current.profile.isOnline;
    final targetStatus =
        targetOnline ? DriverAvailability.online : DriverAvailability.offline;

    state = AsyncData(current.copyWith(isUpdating: true, error: null));

    try {
      final coords = targetOnline ? await _location.getCoordinates() : null;

      final updated = await _repo.setAvailability(
        targetStatus,
        latitude: coords?.latitude,
        longitude: coords?.longitude,
      );

      if (targetOnline) {
        _startLocationBeacon(_onlineBeaconInterval);
      } else {
        _stopLocationBeacon();
      }

      state = AsyncData(
        current.copyWith(
          profile: updated,
          isUpdating: false,
          error: null,
          lastBeaconLatitude: coords?.latitude,
          lastBeaconLongitude: coords?.longitude,
        ),
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
