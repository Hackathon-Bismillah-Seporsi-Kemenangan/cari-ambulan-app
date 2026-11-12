import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/alerts/emergency_alert.dart';
import '../../../../core/logging/app_log.dart';
import '../../../../core/network/api_client.dart';
import '../../data/call_repository.dart';
import '../../data/voice_room.dart';
import '../../domain/call_models.dart';

/// The one voice call of this phone, shared by the patient and driver UIs.
final voiceCallProvider = NotifierProvider<VoiceCallNotifier, VoiceCallState>(
  VoiceCallNotifier.new,
);

class VoiceCallNotifier extends Notifier<VoiceCallState> {
  /// How often the server is asked for a ringing call and the call's status.
  static const pollEvery = Duration(seconds: 3);

  Timer? _incomingPoll;
  bool _checkingIncoming = false;
  String _incomingRole = '';

  Timer? _statusPoll;
  Timer? _durationTimer;
  Timer? _resetTimer;
  VoiceRoom? _room;
  bool _ringing = false;
  bool _disposed = false;

  /// Calls already shown, answered or declined, so a late poll can't ring
  /// them again.
  final _handled = <String>{};

  CallRepository get _repo => ref.read(callRepositoryProvider);

  @override
  VoiceCallState build() {
    ref.onDispose(() {
      _disposed = true;
      _incomingPoll?.cancel();
      _cleanup();
    });
    return const VoiceCallState.idle();
  }

  /// Rings this phone when the other side of the trip calls. On while a
  /// trip is active; turning it off hangs up a call in progress.
  void watchIncoming(bool active, {String peerRole = ''}) {
    if (!active) {
      _incomingPoll?.cancel();
      _incomingPoll = null;
      endCall();
      return;
    }
    _incomingRole = peerRole;
    if (_incomingPoll != null) return;
    _incomingPoll = Timer.periodic(pollEvery, (_) => checkIncoming());
    checkIncoming();
  }

  /// Asks the server for a ringing call now, e.g. when a push says one is
  /// coming. Only while [watchIncoming] is on.
  Future<void> checkIncoming() async {
    if (_incomingPoll == null || _checkingIncoming || state.isActive) return;
    _checkingIncoming = true;
    try {
      final call = await _repo.incoming();
      if (call != null && _incomingPoll != null) _receive(call);
    } on ApiException {
      // Offline for a moment: ask again on the next tick.
    } finally {
      _checkingIncoming = false;
    }
  }

  void _receive(TripCall call) {
    if (state.isActive || _handled.contains(call.id)) return;
    _cleanup();
    _handled.add(call.id);
    state = VoiceCallState(
      status: VoiceCallStatus.incoming,
      callId: call.id,
      peerName: call.callerName,
      peerRole: _incomingRole,
    );
    _ringing = true;
    EmergencyAlert.start(
      title: 'Panggilan masuk',
      body: '${state.displayName} menelepon Anda',
    );
    // Stops ringing when the caller hangs up or the call rings out.
    _watchStatus(call.id);
  }

  /// Calls the other side of the active request [requestId].
  Future<void> startCall({
    required String requestId,
    required String peerName,
    required String peerRole,
  }) async {
    if (state.isActive) return;
    _cleanup();
    state = VoiceCallState(
      status: VoiceCallStatus.dialing,
      peerName: peerName,
      peerRole: peerRole,
      isCaller: true,
    );

    final TripCall call;
    try {
      call = await _repo.start(requestId);
    } on CallAlreadyRinging catch (e) {
      // The other side is calling at the same moment: pick it up, like
      // any phone, instead of failing with "call in progress".
      _handled.add(e.callId);
      state = VoiceCallState(
        status: VoiceCallStatus.incoming,
        callId: e.callId,
        peerName: peerName,
        peerRole: peerRole,
      );
      await accept();
      return;
    } catch (e) {
      _fail(e);
      return;
    }

    // Hung up while the call was being created.
    if (state.status != VoiceCallStatus.dialing) {
      _quietly(_repo.end(call.id));
      return;
    }
    _handled.add(call.id);
    state = state.copyWith(status: VoiceCallStatus.ringing, callId: call.id);
    _watchStatus(call.id);
    await _join(call.id);
  }

  /// "Jawab".
  Future<void> accept() async {
    final callId = state.callId;
    if (state.status != VoiceCallStatus.incoming || callId == null) return;
    _stopRinging();
    _statusPoll?.cancel();
    _markConnected();
    try {
      await _repo.answer(callId);
    } catch (e) {
      _fail(e);
      return;
    }
    _watchStatus(callId);
    await _join(callId);
  }

  /// "Tolak".
  void decline() {
    final callId = state.callId;
    if (state.status != VoiceCallStatus.incoming || callId == null) return;
    _quietly(_repo.decline(callId));
    _finish(after: const Duration(milliseconds: 800));
  }

  /// Hangs up, or stops dialing.
  void endCall() {
    if (!state.isActive) return;
    final callId = state.callId;
    if (callId != null) _quietly(_repo.end(callId));
    _finish(after: const Duration(milliseconds: 1500));
  }

  Future<void> toggleMute() async {
    final muted = !state.isMuted;
    state = state.copyWith(isMuted: muted);
    await _room?.setMuted(muted);
  }

  Future<void> toggleSpeaker() async {
    final speaker = !state.isSpeaker;
    state = state.copyWith(isSpeaker: speaker);
    await _room?.setSpeaker(speaker);
  }

  Future<void> _join(String callId) async {
    try {
      final connection = await _repo.connection(callId);
      if (!_isCurrent(callId)) return;
      final room = _room = ref.read(voiceRoomFactoryProvider)();
      room.onPeerJoined = () {
        if (!_isCurrent(callId)) return;
        state = state.copyWith(audioConnected: true);
        _markConnected();
      };
      room.onClosed = () {
        if (_isCurrent(callId)) endCall();
      };
      await room.connect(url: connection.url, token: connection.token);
    } catch (e) {
      if (_isCurrent(callId)) _fail(e);
    }
  }

  /// Follows the server: answered on the other phone, hung up, declined,
  /// or rang out.
  void _watchStatus(String callId) {
    _statusPoll?.cancel();
    _statusPoll = Timer.periodic(pollEvery, (_) async {
      try {
        final call = await _repo.status(callId);
        if (!_isCurrent(callId)) return;
        if (call.status == 'answered') {
          _markConnected();
        } else if (call.isOver) {
          _finish(
            message: switch (call.status) {
              'declined' when state.isCaller => 'Panggilan ditolak',
              'missed' when state.isCaller => 'Tidak dijawab',
              _ => null,
            },
            after: const Duration(milliseconds: 1500),
          );
        }
      } on ApiException {
        // Try again on the next tick.
      }
    });
  }

  void _markConnected() {
    if (state.status == VoiceCallStatus.connected) return;
    state = state.copyWith(status: VoiceCallStatus.connected);
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(duration: Duration(seconds: timer.tick));
    });
  }

  bool _isCurrent(String callId) =>
      !_disposed && state.isActive && state.callId == callId;

  void _fail(Object error) {
    AppLog.warn('CALL', 'Call failed', error);
    final callId = state.callId;
    if (callId != null) _quietly(_repo.end(callId));
    _finish(
      message: error is ApiException
          ? error.message
          : 'Panggilan gagal tersambung.',
      after: const Duration(milliseconds: 2500),
    );
  }

  /// Shows "ended" for a moment, then goes back to idle.
  void _finish({String? message, required Duration after}) {
    _cleanup();
    final callId = state.callId;
    state = state.copyWith(
      status: VoiceCallStatus.ended,
      errorMessage: message,
    );
    _resetTimer = Timer(after, () {
      if (_disposed) return;
      if (state.status == VoiceCallStatus.ended && state.callId == callId) {
        state = const VoiceCallState.idle();
      }
    });
  }

  void _stopRinging() {
    if (!_ringing) return;
    _ringing = false;
    EmergencyAlert.stop();
  }

  void _cleanup() {
    _stopRinging();
    _statusPoll?.cancel();
    _statusPoll = null;
    _durationTimer?.cancel();
    _durationTimer = null;
    _resetTimer?.cancel();
    _resetTimer = null;
    _room?.dispose();
    _room = null;
  }

  /// Fire and forget: the call is over on this phone either way.
  static void _quietly(Future<void> request) {
    request.then(
      (_) {},
      onError: (Object e) {
        AppLog.warn('CALL', 'Call update not sent', e);
      },
    );
  }
}
