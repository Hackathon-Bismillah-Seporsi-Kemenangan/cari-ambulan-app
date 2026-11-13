enum VoiceCallStatus {
  idle,

  /// Someone is calling this phone; waiting for Jawab / Tolak.
  incoming,
  dialing,
  ringing,
  connected,
  ended,
}

class CallSignalData {
  const CallSignalData({
    required this.callId,
    required this.senderId,
    required this.type,
    required this.data,
  });

  factory CallSignalData.fromJson(Map<String, dynamic> json) {
    return CallSignalData(
      callId: json['call_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      data: json['data'],
    );
  }

  final String callId;
  final String senderId;
  final String type;
  final dynamic data;
}

/// A call ringing for this phone, placed by the other side of the order.
class IncomingCall {
  const IncomingCall({
    required this.id,
    required this.callerName,
    this.token,
    this.roomName,
    this.livekitUrl,
  });

  factory IncomingCall.fromJson(Map<String, dynamic> json) => IncomingCall(
    id: (json['id'] as String? ?? json['call_id'] as String?) ?? '',
    callerName:
        (json['caller'] as Map<String, dynamic>?)?['name'] as String? ??
        json['caller_name'] as String? ??
        '',
    token: json['token'] as String? ?? json['livekit_token'] as String?,
    roomName: json['room_name'] as String? ?? json['room'] as String?,
    livekitUrl: json['livekit_url'] as String?,
  );

  final String id;
  final String callerName;
  final String? token;
  final String? roomName;
  final String? livekitUrl;
}

class VoiceCallState {
  const VoiceCallState({
    required this.status,
    this.callId,
    this.emergencyRequestId,
    this.peerName = '',
    this.peerRole = '',
    this.isCaller = false,
    this.isMuted = false,
    this.isSpeaker = true,
    this.duration = Duration.zero,
    this.errorMessage,
    this.audioConnected = false,
    this.token,
    this.roomName,
    this.livekitUrl,
  });

  const VoiceCallState.idle() : this(status: VoiceCallStatus.idle);

  final VoiceCallStatus status;
  final String? callId;
  final String? emergencyRequestId;
  final String peerName;
  final String peerRole;
  final bool isCaller;
  final bool isMuted;
  final bool isSpeaker;
  final Duration duration;
  final String? errorMessage;

  /// The audio path is up via LiveKit.
  final bool audioConnected;
  final String? token;
  final String? roomName;
  final String? livekitUrl;

  bool get isActive =>
      status == VoiceCallStatus.incoming ||
      status == VoiceCallStatus.dialing ||
      status == VoiceCallStatus.ringing ||
      status == VoiceCallStatus.connected;

  VoiceCallState copyWith({
    VoiceCallStatus? status,
    String? callId,
    String? emergencyRequestId,
    String? peerName,
    String? peerRole,
    bool? isCaller,
    bool? isMuted,
    bool? isSpeaker,
    Duration? duration,
    String? errorMessage,
    bool? audioConnected,
    String? token,
    String? roomName,
    String? livekitUrl,
  }) {
    return VoiceCallState(
      status: status ?? this.status,
      callId: callId ?? this.callId,
      emergencyRequestId: emergencyRequestId ?? this.emergencyRequestId,
      peerName: peerName ?? this.peerName,
      peerRole: peerRole ?? this.peerRole,
      isCaller: isCaller ?? this.isCaller,
      isMuted: isMuted ?? this.isMuted,
      isSpeaker: isSpeaker ?? this.isSpeaker,
      duration: duration ?? this.duration,
      errorMessage: errorMessage ?? this.errorMessage,
      audioConnected: audioConnected ?? this.audioConnected,
      token: token ?? this.token,
      roomName: roomName ?? this.roomName,
      livekitUrl: livekitUrl ?? this.livekitUrl,
    );
  }
}
