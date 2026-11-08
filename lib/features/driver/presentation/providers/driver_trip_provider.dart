import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_log.dart';
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
  }

  final DriverRepository _repository;
  final Ref _ref;

  Future<void> loadActiveTrip() async {
    try {
      final trip = await _repository.getActiveTrip();
      if (!mounted) return;
      state = state.copyWith(trip: trip, clearTrip: trip == null);
    } catch (e) {
      AppLog.error('DRIVER_TRIP', 'Failed loading active trip', e);
    }
  }

  /// Advance to the next logical stage of the trip.
  Future<bool> advanceStage() async {
    final trip = state.trip;
    if (trip == null) return false;

    String? targetStatus;
    switch (trip.status) {
      case EmergencyRequestStatus.driverAssigned:
        targetStatus = 'en_route_to_pickup';
        break;
      case EmergencyRequestStatus.enRouteToPickup:
        targetStatus = 'arrive_at_pickup';
        break;
      case EmergencyRequestStatus.arriveAtPickup:
        targetStatus = 'en_route_to_hospital';
        break;
      case EmergencyRequestStatus.enRouteToHospital:
        targetStatus = 'completed';
        break;
      default:
        return false;
    }

    state = state.copyWith(isUpdating: true, error: null);

    try {
      final updated = await _repository.updateTripStatus(targetStatus);
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
      state = state.copyWith(isUpdating: false, error: 'Gagal memperbarui status: $e');
      return false;
    }
  }
}

