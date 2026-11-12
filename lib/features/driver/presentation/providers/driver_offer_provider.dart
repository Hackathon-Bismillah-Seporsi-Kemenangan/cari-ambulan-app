import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_log.dart';
import '../../../../core/network/api_client.dart';
import '../../../emergency/domain/emergency_models.dart';
import '../../data/driver_repository.dart';
import '../../domain/dispatch_offer_model.dart';
import 'driver_home_provider.dart';

class DriverOfferState {
  const DriverOfferState({
    this.offer,
    this.remainingSeconds = 0,
    this.isResponding = false,
    this.error,
  });

  final DispatchOfferModel? offer;
  final int remainingSeconds;
  final bool isResponding;
  final String? error;

  bool get hasOffer => offer != null && remainingSeconds > 0;

  DriverOfferState copyWith({
    DispatchOfferModel? offer,
    int? remainingSeconds,
    bool? isResponding,
    String? error,
    bool clearOffer = false,
  }) {
    return DriverOfferState(
      offer: clearOffer ? null : (offer ?? this.offer),
      remainingSeconds: clearOffer ? 0 : (remainingSeconds ?? this.remainingSeconds),
      isResponding: isResponding ?? this.isResponding,
      error: error,
    );
  }
}

final driverOfferProvider =
    StateNotifierProvider<DriverOfferNotifier, DriverOfferState>((ref) {
  final repo = ref.watch(driverRepositoryProvider);
  return DriverOfferNotifier(repo);
});

class DriverOfferNotifier extends StateNotifier<DriverOfferState> {
  DriverOfferNotifier(this._repository) : super(const DriverOfferState());

  final DriverRepository _repository;
  Timer? _pollingTimer;
  Timer? _countdownTimer;

  @override
  void dispose() {
    stopPolling();
    _stopCountdown();
    super.dispose();
  }

  void startPolling() {
    stopPolling();
    _poll();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  /// Checks for an offer now, e.g. when a push says one is coming. Only
  /// while polling (the driver is online).
  void pollNow() {
    if (_pollingTimer != null) _poll();
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _stopCountdown();
    if (mounted) {
      state = state.copyWith(clearOffer: true);
    }
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  Future<void> _poll() async {
    // If already showing an offer or responding, don't poll
    if (state.hasOffer || state.isResponding) return;

    try {
      final offer = await _repository.getCurrentOffer();
      if (!mounted) return;

      if (offer != null && offer.secondsRemaining > 0) {
        state = state.copyWith(
          offer: offer,
          remainingSeconds: offer.secondsRemaining,
          error: null,
        );
        _startCountdown();
      }
    } catch (e) {
      AppLog.error('DRIVER_OFFER', 'Failed polling incoming offer', e);
    }
  }

  void _startCountdown() {
    _stopCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (state.remainingSeconds <= 1) {
        _stopCountdown();
        state = state.copyWith(clearOffer: true);
      } else {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      }
    });
  }

  /// Accepts the offer; returns the trip that starts, or null on failure.
  Future<EmergencyRequestModel?> accept() async {
    final offer = state.offer;
    if (offer == null) return null;

    state = state.copyWith(isResponding: true, error: null);
    try {
      final trip = await _repository.acceptRequest(offer.emergencyRequestId);
      _stopCountdown();
      if (mounted) {
        state = state.copyWith(clearOffer: true, isResponding: false);
      }
      return trip;
    } catch (e) {
      if (!mounted) return null;
      state = state.copyWith(
        isResponding: false,
        error: e is ApiException
            ? e.message
            : 'Order sudah tidak tersedia atau koneksi bermasalah.',
      );
      return null;
    }
  }

  Future<void> decline() async {
    final offer = state.offer;
    if (offer == null) return;

    state = state.copyWith(isResponding: true, error: null);
    try {
      await _repository.declineRequest(offer.emergencyRequestId);
    } catch (e) {
      AppLog.error('DRIVER_OFFER', 'Failed declining offer', e);
    } finally {
      _stopCountdown();
      if (mounted) {
        state = state.copyWith(clearOffer: true, isResponding: false);
      }
    }
  }
}
