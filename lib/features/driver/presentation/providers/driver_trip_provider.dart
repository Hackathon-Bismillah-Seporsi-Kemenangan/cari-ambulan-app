import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_log.dart';
import '../../../../core/network/api_client.dart';
import '../../../emergency/domain/emergency_models.dart';
import '../../data/driver_repository.dart';
import 'driver_home_provider.dart';

class DriverTripState {
  const DriverTripState({
    this.trip,
    this.isUpdating = false,
    this.error,
  });

  final EmergencyRequestModel? trip;
  final bool isUpdating;
  final String? error;

  bool get hasActiveTrip => trip != null && trip!.status.isActiveTrip;

  bool get wasCancelled => trip?.status == EmergencyRequestStatus.cancelled;

  DriverTripState copyWith({
    EmergencyRequestModel? trip,
    bool? isUpdating,
    String? error,
    bool clearTrip = false,
  }) {
    return DriverTripState(
      trip: clearTrip ? null : (trip ?? this.trip),
      isUpdating: isUpdating ?? this.isUpdating,
      error: error,
    );
  }
}

final driverTripProvider =
    StateNotifierProvider<DriverTripNotifier, DriverTripState>((ref) {
  final repo = ref.watch(driverRepositoryProvider);
  return DriverTripNotifier(repo, ref);
});

class DriverTripNotifier extends StateNotifier<DriverTripState> {
  DriverTripNotifier(this._repository, this._ref)
      : super(const DriverTripState()) {
    loadActiveTrip();
    // The patient can cancel at any time; nothing else tells the driver.
    _syncTimer = Timer.periodic(syncInterval, (_) {
      if (state.hasActiveTrip && !state.isUpdating) loadActiveTrip();
    });
  }

  static const syncInterval = Duration(seconds: 5);

  final DriverRepository _repository;
  final Ref _ref;
  Timer? _syncTimer;

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> loadActiveTrip() async {
    try {
      final trip = await _repository.getActiveTrip();
      if (!mounted) return;
      final wasActive = state.hasActiveTrip;
      state = state.copyWith(trip: trip, clearTrip: trip == null);
      if (wasActive && !state.hasActiveTrip) {
        // The server put the driver back online.
        _ref.invalidate(driverHomeProvider);
      }
    } catch (e) {
      AppLog.error('DRIVER_TRIP', 'Failed loading active trip', e);
    }
  }

  /// Show the trip the driver just accepted.
  void setTrip(EmergencyRequestModel trip) {
    state = state.copyWith(trip: trip, error: null);
  }

  /// Advance to the next logical stage of the trip.
  Future<bool> advanceStage() async {
    final trip = state.trip;
    if (trip == null) return false;

    final Future<EmergencyRequestModel> Function(String requestId) step;
    switch (trip.status) {
      case EmergencyRequestStatus.driverAssigned:
      case EmergencyRequestStatus.enRouteToPickup:
        step = _repository.markArrived;
        break;
      case EmergencyRequestStatus.arriveAtPickup:
        step = _repository.startToHospital;
        break;
      case EmergencyRequestStatus.enRouteToHospital:
        step = _repository.completeTrip;
        break;
      default:
        return false;
    }

    state = state.copyWith(isUpdating: true, error: null);

    try {
      final updated = await step(trip.id);
      if (!mounted) return true;

      if (updated.status == EmergencyRequestStatus.completed) {
        state = state.copyWith(clearTrip: true, isUpdating: false);
        // Refresh driver profile to show online availability
        _ref.invalidate(driverHomeProvider);
      } else {
        state = state.copyWith(trip: updated, isUpdating: false);
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isUpdating: false,
        error: e is ApiException ? e.message : 'Gagal memperbarui status. Coba lagi.',
      );
      // The order moved on without this app (e.g. the patient cancelled).
      if (e is ApiException && e.isConflict) loadActiveTrip();
      return false;
    }
  }
}

