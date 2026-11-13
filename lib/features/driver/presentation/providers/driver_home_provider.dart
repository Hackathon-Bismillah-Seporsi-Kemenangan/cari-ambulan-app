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
    this.gpsMissing = false,
  });

  final DriverProfile profile;
  final bool isUpdating;
  final String? error;
  final double? lastBeaconLatitude;
  final double? lastBeaconLongitude;

  /// Online, but the last beacon found no GPS fix, so nothing was sent and
  /// dispatch still has an older position.
  final bool gpsMissing;

  DriverHomeState copyWith({
    DriverProfile? profile,
    bool? isUpdating,
    String? error,
    double? lastBeaconLatitude,
    double? lastBeaconLongitude,
    bool? gpsMissing,
  }) {
    return DriverHomeState(
      profile: profile ?? this.profile,
      isUpdating: isUpdating ?? this.isUpdating,
      error: error,
      lastBeaconLatitude: lastBeaconLatitude ?? this.lastBeaconLatitude,
      lastBeaconLongitude: lastBeaconLongitude ?? this.lastBeaconLongitude,
      gpsMissing: gpsMissing ?? this.gpsMissing,
    );
  }
}

final driverHomeProvider =
    AsyncNotifierProvider<DriverHomeNotifier, DriverHomeState>(
      DriverHomeNotifier.new,
    );

/// Shown when going online finds no position: dispatch matches orders by
/// it, so the driver stays offline rather than being placed somewhere else.
const noGpsToGoOnline =
    'Lokasi (GPS) tidak ditemukan. Aktifkan lokasi untuk mulai menerima '
    'order darurat.';

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
        // A fresh fix only: a guessed or stale point would make dispatch
        // send this ambulance to orders it is nowhere near.
        final pos = await _location.getCurrentPosition();
        if (pos == null) {
          if (!current.gpsMissing) {
            state = AsyncData(current.copyWith(gpsMissing: true));
          }
          return;
        }
        await _repo.sendLocation(pos.latitude, pos.longitude);
        state = AsyncData(
          (state.value ?? current).copyWith(
            lastBeaconLatitude: pos.latitude,
            lastBeaconLongitude: pos.longitude,
            gpsMissing: false,
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
    final targetStatus = targetOnline
        ? DriverAvailability.online
        : DriverAvailability.offline;

    state = AsyncData(current.copyWith(isUpdating: true, error: null));

    try {
      final coords = targetOnline ? await _location.emergencyFix() : null;
      if (targetOnline && coords == null) {
        state = AsyncData(
          current.copyWith(isUpdating: false, error: noGpsToGoOnline),
        );
        return;
      }

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
          // The availability response has no trip count; keep the last one.
          profile: updated.copyWith(
            completedTripsToday: current.profile.completedTripsToday,
          ),
          isUpdating: false,
          error: null,
          lastBeaconLatitude: coords?.latitude,
          lastBeaconLongitude: coords?.longitude,
          gpsMissing: false,
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
