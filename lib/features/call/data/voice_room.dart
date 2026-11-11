import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/logging/app_log.dart';

/// A new audio room per call; tests swap in a fake.
final voiceRoomFactoryProvider = Provider<VoiceRoom Function()>(
  (ref) => LiveKitVoiceRoom.new,
);

/// The audio of one call.
abstract class VoiceRoom {
  /// Joins the room with the microphone on and the speakerphone on.
  Future<void> connect({required String url, required String token});

  /// The other side joined: their voice can be heard.
  void Function()? onPeerJoined;

  /// The other side left, or the connection dropped for good.
  void Function()? onClosed;

  Future<void> setMuted(bool muted);
  Future<void> setSpeaker(bool speaker);
  Future<void> dispose();
}

class LiveKitVoiceRoom implements VoiceRoom {
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  @override
  void Function()? onPeerJoined;

  @override
  void Function()? onClosed;

  @override
  Future<void> connect({required String url, required String token}) async {
    final room = _room = Room(
      roomOptions: const RoomOptions(
        defaultAudioPublishOptions: AudioPublishOptions(dtx: true),
      ),
    );
    _listener = room.createListener()
      ..on<ParticipantConnectedEvent>((_) => onPeerJoined?.call())
      ..on<TrackSubscribedEvent>((event) {
        if (event.track is AudioTrack) onPeerJoined?.call();
      })
      ..on<ParticipantDisconnectedEvent>((_) => onClosed?.call())
      ..on<RoomDisconnectedEvent>((event) {
        AppLog.info('CALL', 'Room closed: ${event.reason}');
        onClosed?.call();
      });

    await room.connect(url, token);
    // Joined after the other side: they are already there.
    if (room.remoteParticipants.isNotEmpty) onPeerJoined?.call();
    await room.localParticipant?.setMicrophoneEnabled(true);
    await setSpeaker(true);
  }

  @override
  Future<void> setMuted(bool muted) async {
    await _room?.localParticipant?.setMicrophoneEnabled(!muted);
  }

  @override
  Future<void> setSpeaker(bool speaker) async {
    try {
      await Hardware.instance.setSpeakerphoneOn(speaker);
    } catch (e) {
      AppLog.warn('CALL', 'Speakerphone toggle failed', e);
    }
  }

  @override
  Future<void> dispose() async {
    onPeerJoined = null;
    onClosed = null;
    await _listener?.dispose();
    _listener = null;
    try {
      await _room?.disconnect();
      await _room?.dispose();
    } catch (e) {
      AppLog.warn('CALL', 'Leaving the room failed', e);
    }
    _room = null;
  }
}
