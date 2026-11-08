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
  const EmergencyInitial();
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

  void _startPolling() {
    _stopPolling();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _pollStatus();
    });
  }

  Future<void> _pollStatus() async {
    try {
      final current = await _repository.getCurrentRequest();
      if (!mounted) return;

      if (current == null) {
        _stopPolling();
        state = const EmergencyInitial();
        return;
      }

      state = EmergencyActive(current);

      if (current.status == EmergencyRequestStatus.completed ||
          current.status == EmergencyRequestStatus.cancelled) {
        _stopPolling();
      }
    } catch (e) {
      AppLog.error('EMERGENCY', 'Failed polling emergency status', e);
    }
  }

  /// Check if user already has an active emergency upon opening app.
  Future<void> checkActiveRequest() async {
    try {
      final current = await _repository.getCurrentRequest();
      if (!mounted) return;

      if (current != null &&
          current.status != EmergencyRequestStatus.cancelled &&
          current.status != EmergencyRequestStatus.completed) {
        state = EmergencyActive(current);
        if (current.status.isSearching) {
          _startPolling();
        }
      } else {
        state = const EmergencyInitial();
      }
    } catch (e) {
      AppLog.error('EMERGENCY', 'Error checking active emergency', e);
    }
  }

  /// Trigger emergency SOS call.
  Future<void> triggerSOS({
    String emergencyType = 'Darurat Umum',
    String? notes,
  }) async {
    state = const EmergencyLoading(message: 'Mendeteksi lokasi & memanggil ambulans...');

    try {
      final coords = await _locationService.getCoordinates();
      final address = await _locationService.getAddressFromCoordinates(
        coords.latitude,
        coords.longitude,
      );

      final request = await _repository.createEmergencyRequest(
        latitude: coords.latitude,
        longitude: coords.longitude,
        address: address,
        emergencyType: emergencyType,
        notes: notes,
      );

      if (!mounted) return;
      state = EmergencyActive(request);
      _startPolling();
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
