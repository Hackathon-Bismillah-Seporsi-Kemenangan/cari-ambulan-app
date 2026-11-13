import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../call/domain/call_models.dart';
import '../../../call/presentation/providers/voice_call_provider.dart';
import '../providers/trip_call_provider.dart';

/// Hands the reporter's call to the same call screen the reporter's app uses.
///
/// The poll below is a fallback for a push that never arrived; the call
/// provider ignores a call it already showed, answered or declined.
class TripCallOverlay extends ConsumerStatefulWidget {
  const TripCallOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TripCallOverlay> createState() => _TripCallOverlayState();
}

class _TripCallOverlayState extends ConsumerState<TripCallOverlay> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(tripCallProvider, (_, next) {
      final call = next.value;
      if (call == null || !call.isRinging) return;
      ref
          .read(voiceCallProvider.notifier)
          .receiveCall(
            IncomingCall(id: call.id, callerName: call.callerName),
            peerRole: 'Pasien / Keluarga',
          );
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Compact bar at the top of the trip sheet while a call is dialing or
/// connected, so navigation and the trip buttons stay usable. Driven by the
/// same call state as the full-screen call screen.
class ActiveCallBar extends ConsumerWidget {
  const ActiveCallBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(voiceCallProvider);
    final onCall =
        call.status == VoiceCallStatus.dialing ||
        call.status == VoiceCallStatus.ringing ||
        call.status == VoiceCallStatus.connected;
    if (!onCall) return const SizedBox.shrink();

    final connected = call.status == VoiceCallStatus.connected;
    final name = call.peerName.isEmpty ? call.peerRole : call.peerName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.callSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.callSurfaceLight,
              child: Icon(
                Icons.person_outline_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    connected
                        ? 'LiveKit · ${_formatDuration(call.duration)}'
                        : 'Memanggil…',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.callAccent,
                    ),
                  ),
                ],
              ),
            ),
            if (connected) ...[
              IconButton(
                icon: Icon(
                  call.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: call.isMuted ? AppColors.warning : Colors.white70,
                  size: 22,
                ),
                tooltip: call.isMuted ? 'Batal bisu' : 'Bisu',
                onPressed: () =>
                    ref.read(voiceCallProvider.notifier).toggleMute(),
              ),
              IconButton(
                icon: Icon(
                  call.isSpeaker
                      ? Icons.volume_up_rounded
                      : Icons.volume_down_rounded,
                  color: Colors.white70,
                  size: 22,
                ),
                tooltip: call.isSpeaker ? 'Speakerphone' : 'Earpiece',
                onPressed: () =>
                    ref.read(voiceCallProvider.notifier).toggleSpeaker(),
              ),
              const SizedBox(width: 4),
            ],
            Material(
              color: AppColors.emergency,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => ref.read(voiceCallProvider.notifier).endCall(),
                child: const Tooltip(
                  message: 'Akhiri panggilan',
                  child: SizedBox.square(
                    dimension: 44,
                    child: Icon(
                      Icons.call_end_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(Duration d) {
  final minutes = d.inMinutes.toString().padLeft(2, '0');
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
