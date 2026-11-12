import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/logging/app_log.dart';
import '../../../../core/network/api_client.dart';
import '../../data/api_emergency_repository.dart';
import '../../data/emergency_repository.dart';
import '../../domain/emergency_models.dart';

final emergencyProvider =
    StateNotifierProvider<EmergencyNotifier, EmergencyState>((ref) {
  final repo = ref.watch(emergencyRepositoryProvider);
  final locationService = ref.watch(locationServiceProvider);
  return EmergencyNotifier(repo, locationService);
});

sealed class EmergencyState {
  const EmergencyState();
}

class EmergencyInitial extends EmergencyState {
  const EmergencyInitial({this.closed});

  /// The request that just ended without the user cancelling it here:
  /// handed over at the IGD, or cancelled elsewhere. Null otherwise.
  final EmergencyRequestModel? closed;
}

class EmergencyLoading extends EmergencyState {
  const EmergencyLoading({this.message});
  final String? message;
}

class EmergencyActive extends EmergencyState {
  const EmergencyActive(this.request);
  final EmergencyRequestModel request;
}

class EmergencyError extends EmergencyState {
  const EmergencyError(this.message);
  final String message;
}

class EmergencyNotifier extends StateNotifier<EmergencyState> {
  EmergencyNotifier(this._repository, this._locationService)
      : super(const EmergencyInitial()) {
    checkActiveRequest();
  }

  final EmergencyRepository _repository;
  final LocationService _locationService;
  Timer? _pollingTimer;

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Follows the open request by id, so its search progress and the end of
  /// the trip are seen (`current` only lists open requests).
  void _startPolling(String id) {
    _stopPolling();
    _pollingTimer = Timer.periodic(pollInterval, (_) => _pollStatus(id));
  }

  static const pollInterval = Duration(seconds: 3);

  Future<void> _pollStatus(String id) async {
    try {
      _show(await _repository.getRequest(id));
    } on ApiException catch (e) {
      if (!mounted) return;
      // Gone or not ours any more: nothing left to follow.
      if (e.statusCode == 404) {
        _stopPolling();
        state = const EmergencyInitial();
      } else {
        AppLog.error('EMERGENCY', 'Failed polling emergency status', e);
      }
    } catch (e) {
      AppLog.error('EMERGENCY', 'Failed polling emergency status', e);
    }
  }

  /// Shows [request], or returns home once it is closed.
  void _show(EmergencyRequestModel request) {
    if (!mounted) return;
    if (request.status.isClosed) {
      _stopPolling();
      state = EmergencyInitial(closed: request);
    } else {
      state = EmergencyActive(request);
    }
  }

  /// Widens the search to the next radius step.
  Future<void> widenRadius() => _updateSearch(_repository.widenRadius);

  /// Searches the full radius again after nobody accepted.
  Future<void> retrySearch() => _updateSearch(_repository.retrySearch);

  Future<void> _updateSearch(
    Future<EmergencyRequestModel> Function(String id) update,
  ) async {
    final current = state;
    if (current is! EmergencyActive || !current.request.status.isSearching) {
      return;
    }
    try {
      _show(await update(current.request.id));
    } on ApiException catch (e) {
      // 409: a driver accepted meanwhile; the next poll shows the ambulance.
      AppLog.warn('EMERGENCY', 'Search update failed', e);
      if (!e.isConflict) rethrow;
    }
  }

  /// Check if user already has an active emergency upon opening app.
  Future<void> checkActiveRequest() async {
    try {
      final current = await _repository.getCurrentRequest();
      if (!mounted) return;

      if (current != null && !current.status.isClosed) {
        state = EmergencyActive(current);
        _startPolling(current.id);
      } else {
        state = const EmergencyInitial();
      }
    } catch (e) {
      AppLog.error('EMERGENCY', 'Error checking active emergency', e);
    }
  }

  /// Trigger emergency SOS call, to [pickup] (a saved address) or else to
  /// where the phone is.
  Future<void> triggerSOS({
    String emergencyType = 'Darurat Umum',
    String? notes,
    EmergencyLocation? pickup,
  }) async {
    state = EmergencyLoading(
      message: pickup == null
          ? 'Mendeteksi lokasi & memanggil ambulans...'
          : 'Memanggil ambulans ke alamat tersimpan...',
    );

    try {
      final EmergencyLocation at;
      if (pickup != null) {
        at = pickup;
      } else {
        final coords = await _locationService.getCoordinates();
        at = EmergencyLocation(
          latitude: coords.latitude,
          longitude: coords.longitude,
          address: await _locationService.getAddressFromCoordinates(
            coords.latitude,
            coords.longitude,
          ),
        );
      }

      final request = await _repository.createEmergencyRequest(
        latitude: at.latitude,
        longitude: at.longitude,
        address: at.address,
        emergencyType: emergencyType,
        notes: notes,
      );

      if (!mounted) return;
      state = EmergencyActive(request);
      _startPolling(request.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isConflict) {
        await checkActiveRequest();
      } else {
        state = EmergencyError(e.message);
      }
    } catch (e) {
      if (!mounted) return;
      state = EmergencyError('Gagal mengirim panggilan SOS: $e');
    }
  }

  /// Cancel current emergency request.
  Future<void> cancelRequest({String? reason}) async {
    final current = state;
    if (current is! EmergencyActive) return;

    state = const EmergencyLoading(message: 'Membatalkan panggilan...');
    _stopPolling();

    try {
      await _repository.cancelRequest(current.request.id, reason: reason);
      if (!mounted) return;
      state = const EmergencyInitial();
    } catch (e) {
      if (!mounted) return;
      state = EmergencyError('Gagal membatalkan: $e');
    }
  }
}
