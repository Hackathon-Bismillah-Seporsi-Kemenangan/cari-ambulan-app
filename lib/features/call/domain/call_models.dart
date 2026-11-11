enum VoiceCallStatus {
  idle,

  /// The other side is calling this phone; waiting for Jawab / Tolak.
  incoming,

  /// Creating the call on the server.
  dialing,

  /// The other phone is ringing.
  ringing,
  connected,
  ended,
}

/// A call between the patient and the driver of an active trip
/// (`TripCallResource`).
class TripCall {
  const TripCall({
    required this.id,
    required this.status,
    this.callerName = '',
  });

  factory TripCall.fromJson(Map<String, dynamic> json) => TripCall(
    id: json['id'] as String,
    status: json['status'] as String? ?? 'ringing',
    callerName:
        (json['caller'] as Map<String, dynamic>?)?['name'] as String? ?? '',
  );

  final String id;

  /// `ringing`, `answered`, `ended`, `declined` or `missed`.
  final String status;
  final String callerName;

  bool get isOver =>
      status == 'ended' || status == 'declined' || status == 'missed';
}

/// Where to join the call's audio room.
typedef CallConnection = ({String url, String token});

class VoiceCallState {
  const VoiceCallState({
    required this.status,
    this.callId,
    this.peerName = '',
    this.peerRole = '',
    this.isCaller = false,
    this.isMuted = false,
    this.isSpeaker = true,
    this.audioConnected = false,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  const VoiceCallState.idle() : this(status: VoiceCallStatus.idle);

  final VoiceCallStatus status;
  final String? callId;
  final String peerName;

  /// Shown when the peer's name is unknown: "Driver Ambulans", "Pasien".
  final String peerRole;
  final bool isCaller;
  final bool isMuted;
  final bool isSpeaker;

  /// The audio path is up.
  final bool audioConnected;
  final Duration duration;
  final String? errorMessage;

  String get displayName => peerName.isEmpty ? peerRole : peerName;

  bool get isActive =>
      status == VoiceCallStatus.incoming ||
      status == VoiceCallStatus.dialing ||
      status == VoiceCallStatus.ringing ||
      status == VoiceCallStatus.connected;

  VoiceCallState copyWith({
    VoiceCallStatus? status,
    String? callId,
    bool? isMuted,
    bool? isSpeaker,
    bool? audioConnected,
    Duration? duration,
    String? errorMessage,
  }) {
    return VoiceCallState(
      status: status ?? this.status,
      callId: callId ?? this.callId,
      peerName: peerName,
      peerRole: peerRole,
      isCaller: isCaller,
      isMuted: isMuted ?? this.isMuted,
      isSpeaker: isSpeaker ?? this.isSpeaker,
      audioConnected: audioConnected ?? this.audioConnected,
      duration: duration ?? this.duration,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
