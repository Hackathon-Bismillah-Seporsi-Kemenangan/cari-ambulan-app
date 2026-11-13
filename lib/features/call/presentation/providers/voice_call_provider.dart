import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_log.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_providers.dart';
import '../../../../core/notifications/fcm_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/livekit_voice_service.dart';
import '../../domain/call_models.dart';

final voiceCallProvider = NotifierProvider<VoiceCallNotifier, VoiceCallState>(
  VoiceCallNotifier.new,
);

/// How often both sides poll call status from the server to catch terminations.
const _statusPollEvery = Duration(seconds: 3);

class VoiceCallNotifier extends Notifier<VoiceCallState> {
  LiveKitVoiceService? _livekit;
  Timer? _durationTimer;
  Timer? _statusPoll;
  Timer? _resetTimer;

  /// Vibrates while an incoming call rings.
  Timer? _ringTimer;

  /// Calls already shown, answered or declined, so a poll still in flight
  /// can't ring them again.
  final _handledCalls = <String>{};

  @override
  VoiceCallState build() {
    FcmService.onIncomingCall = (incoming) {
      receiveCall(incoming);
    };
    final pending = FcmService.pendingCall;
    if (pending != null) {
      FcmService.pendingCall = null;
      Future.microtask(() => receiveCall(pending));
    }
    ref.onDispose(() {
      FcmService.onIncomingCall = null;
      _cleanup();
    });
    return const VoiceCallState.idle();
  }

  /// Calling the other side of the active emergency request: the patient
  /// calls the driver, or the driver calls the patient.
  Future<void> startCall({
    required String emergencyRequestId,
    required String peerName,
    String peerRole = 'Driver Ambulans',
  }) async {
    final client = ref.read(apiClientProvider);
    final user = ref.read(authProvider).value;
    if (user == null) return;
    // Already calling (a second tap, or the other side's call is ringing).
    if (state.isActive) return;

    _cleanup();
    state = VoiceCallState(
      status: VoiceCallStatus.dialing,
      emergencyRequestId: emergencyRequestId,
      peerName: peerName,
      peerRole: peerRole,
      isCaller: true,
    );

    try {
      // 1. Create call record on server; server creates LiveKit room & issues token
      final res = await client.post(
        'emergency-requests/$emergencyRequestId/calls',
      );
      final data = res?['data'] as Map<String, dynamic>? ?? res;
      final callId = (data?['id'] as String?) ?? (data?['call_id'] as String?);

      if (callId == null) {
        throw StateError('Gagal membuat panggilan.');
      }

      final token = data?['token'] as String? ??
          data?['livekit_token'] as String? ??
          (data?['connection'] as Map<String, dynamic>?)?['token'] as String?;
      final livekitUrl = data?['url'] as String? ??
          data?['livekit_url'] as String? ??
          (data?['connection'] as Map<String, dynamic>?)?['server_url'] as String? ??
          ApiConfig.livekitUrl;
      final roomName = data?['room_name'] as String? ??
          data?['room'] as String? ??
          (data?['connection'] as Map<String, dynamic>?)?['room_name'] as String?;

      _handledCalls.add(callId);
      state = state.copyWith(
        callId: callId,
        status: VoiceCallStatus.ringing,
        token: token,
        roomName: roomName,
        livekitUrl: livekitUrl,
      );

      // 2. Connect to LiveKit room
      await _join(callId: callId, token: token, url: livekitUrl);
    } on ApiException catch (e) {
      // The other side is already calling us: pressing "Telepon" answers it,
      // like any phone, instead of failing with "call in progress".
      final ringingId = e.body?['incoming_call_id'] as String?;
      if (e.isConflict && ringingId != null) {
        _cleanup();
        state = const VoiceCallState.idle();
        _handledCalls.remove(ringingId);
        if (receiveCall(
          IncomingCall(id: ringingId, callerName: peerName),
          peerRole: peerRole,
        )) {
          await acceptIncoming();
        }
        return;
      }
      _fail('Failed to start call', e);
    } catch (e) {
      _fail('Failed to start call', e);
    }
  }

  /// Driver answering an incoming call from the patient.
  Future<void> answerCall({
    required String callId,
    required String peerName,
    String peerRole = 'Pasien / Keluarga',
    String? token,
    String? url,
  }) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    _cleanup();
    _handledCalls.add(callId);
    state = VoiceCallState(
      status: VoiceCallStatus.connected,
      callId: callId,
      peerName: peerName,
      peerRole: peerRole,
      isCaller: false,
      token: token,
      livekitUrl: url,
    );

    try {
      await _join(callId: callId, token: token, url: url);
      _startTimer();
    } catch (e) {
      _fail('Failed to answer call', e);
    }
  }

  /// The other side is calling this phone: rings until [acceptIncoming],
  /// [declineIncoming], or the caller gives up.
  bool receiveCall(IncomingCall call, {String? peerRole}) {
    if (state.isActive || _handledCalls.contains(call.id)) return false;
    peerRole ??= (ref.read(authProvider).value?.isDriver ?? false)
        ? 'Pasien / Keluarga'
        : 'Driver Ambulans';

    _cleanup();
    _handledCalls.add(call.id);
    state = VoiceCallState(
      status: VoiceCallStatus.incoming,
      callId: call.id,
      peerName: call.callerName,
      peerRole: peerRole,
      token: call.token,
      roomName: call.roomName,
      livekitUrl: call.livekitUrl,
    );

    _ring();
    _playSiren();
    _ringTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      _ring();
    });
    // Stops ringing when the caller hangs up or the call rings out.
    _statusPoll = Timer.periodic(_statusPollEvery, (_) => _pollStatus(call.id));
    return true;
  }

  /// The looping alarm siren (MainActivity.kt) at full alarm volume, so a call
  /// is heard on silent and over a locked screen. Best effort: tests and
  /// platforms without it just skip the sound.
  static const _ringtone = MethodChannel('cari_ambulan/ringtone');

  void _playSiren() {
    _ringtone.invokeMethod<void>('play').catchError((_) {});
  }

  void _ring() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  /// "Jawab" on an incoming call.
  Future<void> acceptIncoming() async {
    final callId = state.callId;
    if (state.status != VoiceCallStatus.incoming || callId == null) return;

    _stopRinging();
    _statusPoll?.cancel();
    state = state.copyWith(status: VoiceCallStatus.connected);
    try {
      Map<String, dynamic>? data;
      try {
        final res =
            await ref.read(apiClientProvider).post('calls/$callId/accept');
        data = res?['data'] as Map<String, dynamic>? ?? res;
      } catch (_) {
        final res =
            await ref.read(apiClientProvider).post('calls/$callId/answer');
        data = res?['data'] as Map<String, dynamic>? ?? res;
      }

      final token = data?['token'] as String? ??
          data?['livekit_token'] as String? ??
          (data?['connection'] as Map<String, dynamic>?)?['token'] as String? ??
          state.token;
      final url = data?['url'] as String? ??
          data?['livekit_url'] as String? ??
          (data?['connection'] as Map<String, dynamic>?)?['server_url'] as String? ??
          state.livekitUrl ??
          ApiConfig.livekitUrl;

      await _join(callId: callId, token: token, url: url);
      _startTimer();
    } catch (e) {
      _fail('Failed to answer call', e);
    }
  }

  /// "Tolak" on an incoming call.
  Future<void> declineIncoming() async {
    final callId = state.callId;
    if (state.status != VoiceCallStatus.incoming || callId == null) return;

    state = state.copyWith(status: VoiceCallStatus.ended);
    _cleanup();
    _resetLater(callId, const Duration(milliseconds: 800));
    try {
      await ref.read(apiClientProvider).post('calls/$callId/decline');
    } catch (e) {
      AppLog.warn('VoiceCall', 'Failed to decline call', e);
    }
  }

  void _stopRinging() {
    _ringTimer?.cancel();
    if (_ringTimer != null) {
      _ringtone.invokeMethod<void>('stop').catchError((_) {});
    }
    _ringTimer = null;
  }

  Future<void> _join({
    required String callId,
    String? token,
    String? url,
  }) async {
    final client = ref.read(apiClientProvider);
    final resolvedToken = await _resolveToken(client, callId, token);
    final livekitUrl = url ?? ApiConfig.livekitUrl;

    final livekit = _livekit = LiveKitVoiceService();

    livekit.onConnectionState = (connState) {
      AppLog.info('VoiceCall', 'LiveKit connection state: $connState');
      if (connState == LiveKitCallConnectionState.connected) {
        // The caller only reached the room: the call is "connected" (timer
        // running) once the other side answers, not while it still rings.
        if (!state.isCaller) _markConnected();
        state = state.copyWith(audioConnected: true);
      } else if (connState == LiveKitCallConnectionState.failed) {
        _fail('LiveKit connection failed', 'Koneksi suara gagal');
      } else if (connState == LiveKitCallConnectionState.disconnected) {
        endCall(notifyServer: false);
      }
    };

    livekit.onParticipantJoined = (participantId) {
      AppLog.info(
        'VoiceCall',
        'Participant $participantId joined LiveKit room',
      );
      _markConnected();
      state = state.copyWith(audioConnected: true);
    };

    livekit.onParticipantLeft = (participantId) {
      AppLog.info('VoiceCall', 'Participant $participantId left LiveKit room');
      endCall();
    };

    if (resolvedToken != null && resolvedToken.isNotEmpty) {
      try {
        await livekit.connect(url: livekitUrl, token: resolvedToken);
      } catch (e) {
        AppLog.warn('VoiceCall', 'LiveKit connect error', e);
      }
    }

    _statusPoll = Timer.periodic(_statusPollEvery, (_) => _pollStatus(callId));
  }

  Future<String?> _resolveToken(
    ApiClient client,
    String callId,
    String? existingToken,
  ) async {
    if (existingToken != null && existingToken.isNotEmpty) return existingToken;
    try {
      final res = await client.get('calls/$callId/token');
      final data = res?['data'] as Map<String, dynamic>? ?? res;
      return data?['token'] as String? ??
          data?['livekit_token'] as String? ??
          (data?['connection'] as Map<String, dynamic>?)?['token'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pollStatus(String callId) async {
    try {
      final res = await ref.read(apiClientProvider).get('calls/$callId');
      final data = res?['data'] as Map<String, dynamic>?;
      final status = data?['status'] as String?;
      if (status != null) {
        _onCallStatus(status);
      }

      // If token wasn't ready earlier and becomes available now
      if ((_livekit == null || !state.audioConnected) && data != null) {
        final token =
            data['token'] as String? ?? data['livekit_token'] as String?;
        if (token != null && token.isNotEmpty && token != state.token) {
          state = state.copyWith(token: token);
          final url = data['livekit_url'] as String? ?? ApiConfig.livekitUrl;
          await _livekit?.connect(url: url, token: token);
        }
      }
    } catch (e) {
      AppLog.debug('VoiceCall', 'Call status unavailable: $e');
    }
  }

  void _onCallStatus(String status) {
    switch (status) {
      case 'answered':
        _markConnected();
      case 'ended' || 'declined' || 'missed':
        endCall(notifyServer: false);
    }
  }

  void _markConnected() {
    if (state.status == VoiceCallStatus.connected) return;
    state = state.copyWith(status: VoiceCallStatus.connected);
    _startTimer();
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(duration: Duration(seconds: timer.tick));
    });
  }

  Future<void> toggleMute() async {
    final next = !state.isMuted;
    await _livekit?.setMuted(next);
    state = state.copyWith(isMuted: next);
  }

  Future<void> toggleSpeaker() async {
    final next = !state.isSpeaker;
    await _livekit?.setSpeakerphone(next);
    state = state.copyWith(isSpeaker: next);
  }

  Future<void> endCall({bool notifyServer = true}) async {
    if (!state.isActive) return;
    final callId = state.callId;
    if (notifyServer && callId != null) _notifyEnded(callId);

    state = state.copyWith(status: VoiceCallStatus.ended);
    _cleanup();
    _resetLater(callId, const Duration(milliseconds: 1500));
  }

  void _fail(String what, Object error) {
    AppLog.warn('VoiceCall', what, error);
    final callId = state.callId;
    if (callId != null) _notifyEnded(callId);
    state = state.copyWith(
      status: VoiceCallStatus.ended,
      errorMessage: error is ApiException
          ? error.message
          : 'Panggilan gagal tersambung.',
    );
    _cleanup();
    _resetLater(callId, const Duration(milliseconds: 2500));
  }

  void _notifyEnded(String callId) {
    ref.read(apiClientProvider).post('calls/$callId/end').ignore();
  }

  void _resetLater(String? callId, Duration after) {
    _resetTimer?.cancel();
    _resetTimer = Timer(after, () {
      if (!ref.mounted) return;
      if (state.status == VoiceCallStatus.ended && state.callId == callId) {
        state = const VoiceCallState.idle();
      }
    });
  }

  void _cleanup() {
    _stopRinging();
    _durationTimer?.cancel();
    _durationTimer = null;
    _statusPoll?.cancel();
    _statusPoll = null;
    _resetTimer?.cancel();
    _resetTimer = null;
    _livekit?.dispose();
    _livekit = null;
  }
}
