import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import '../../../core/logging/app_log.dart';

enum LiveKitCallConnectionState {
  connecting,
  connected,
  reconnecting,
  disconnected,
  failed,
}

typedef OnLiveKitConnectionState =
    void Function(LiveKitCallConnectionState state);
typedef OnLiveKitParticipantEvent = void Function(String participantId);

class LiveKitVoiceService {
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  bool _isMuted = false;
  bool _isSpeaker = true;

  bool get isMuted => _isMuted;
  bool get isSpeaker => _isSpeaker;

  OnLiveKitConnectionState? onConnectionState;
  OnLiveKitParticipantEvent? onParticipantJoined;
  OnLiveKitParticipantEvent? onParticipantLeft;

  Future<void> connect({required String url, required String token}) async {
    await dispose();

    final room = _room = Room(
      roomOptions: const RoomOptions(
        defaultAudioPublishOptions: AudioPublishOptions(dtx: true),
      ),
    );

    final listener = _listener = room.createListener();

    listener
      ..on<RoomConnectedEvent>((event) {
        AppLog.info('LiveKit', 'Connected to room: ${room.name}');
        onConnectionState?.call(LiveKitCallConnectionState.connected);
      })
      ..on<RoomReconnectingEvent>((event) {
        AppLog.warn('LiveKit', 'Reconnecting to room: ${room.name}');
        onConnectionState?.call(LiveKitCallConnectionState.reconnecting);
      })
      ..on<RoomReconnectedEvent>((event) {
        AppLog.info('LiveKit', 'Reconnected to room: ${room.name}');
        onConnectionState?.call(LiveKitCallConnectionState.connected);
      })
      ..on<RoomDisconnectedEvent>((event) {
        AppLog.info(
          'LiveKit',
          'Disconnected from room: ${room.name} reason: ${event.reason}',
        );
        onConnectionState?.call(LiveKitCallConnectionState.disconnected);
      })
      ..on<ParticipantConnectedEvent>((event) {
        AppLog.info(
          'LiveKit',
          'Participant joined: ${event.participant.identity}',
        );
        onParticipantJoined?.call(event.participant.identity);
        onConnectionState?.call(LiveKitCallConnectionState.connected);
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        AppLog.info(
          'LiveKit',
          'Participant left: ${event.participant.identity}',
        );
        onParticipantLeft?.call(event.participant.identity);
      })
      ..on<TrackSubscribedEvent>((event) {
        if (event.track is AudioTrack) {
          AppLog.info(
            'LiveKit',
            'Remote audio track subscribed: ${event.track.sid}',
          );
          onConnectionState?.call(LiveKitCallConnectionState.connected);
        }
      });

    try {
      onConnectionState?.call(LiveKitCallConnectionState.connecting);
      await room.connect(url, token);

      // Enable microphone by default for the call
      await room.localParticipant?.setMicrophoneEnabled(true);
      _isMuted = false;

      // Default to speakerphone for emergency calls
      await setSpeakerphone(true);
    } catch (e) {
      AppLog.warn('LiveKit', 'Failed to connect to LiveKit', e);
      onConnectionState?.call(LiveKitCallConnectionState.failed);
      rethrow;
    }
  }

  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(!muted);
    } catch (e) {
      AppLog.warn('LiveKit', 'Failed to toggle microphone', e);
    }
  }

  Future<void> setSpeakerphone(bool speaker) async {
    _isSpeaker = speaker;
    try {
      await Hardware.instance.setSpeakerphoneOn(speaker);
    } catch (e) {
      AppLog.warn('LiveKit', 'Failed to toggle speakerphone', e);
    }
  }

  Future<void> dispose() async {
    try {
      _listener?.dispose();
      _listener = null;
      await _room?.disconnect();
      await _room?.dispose();
      _room = null;
    } catch (e) {
      AppLog.warn('LiveKit', 'Error disposing LiveKit room', e);
    }
  }
}
