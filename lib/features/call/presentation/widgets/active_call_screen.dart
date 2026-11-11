import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/call_models.dart';
import '../providers/voice_call_provider.dart';

/// Full-screen call, like a phone's: Jawab / Tolak while ringing, then
/// mute, hang up and speaker.
class ActiveCallScreen extends ConsumerWidget {
  const ActiveCallScreen({super.key, this.closeOnAnswer = false});

  /// The driver goes back to the map once they pick up; the call continues
  /// in [ActiveCallBar].
  final bool closeOnAnswer;

  static bool _open = false;

  /// Opens the screen once, however many times it's asked for the same call.
  static void show(BuildContext context, {bool closeOnAnswer = false}) {
    if (_open) return;
    _open = true;
    showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: AppColors.callSurface,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => PopScope(
        canPop: false,
        child: Material(
          color: AppColors.callSurface,
          child: ActiveCallScreen(closeOnAnswer: closeOnAnswer),
        ),
      ),
    ).whenComplete(() => _open = false);
  }

  /// Closes this screen only, even if another page was pushed on top.
  static void _close(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route != null && route.isActive) {
      Navigator.of(context).removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<VoiceCallState>(voiceCallProvider, (previous, next) {
      final answered =
          closeOnAnswer &&
          previous?.status == VoiceCallStatus.incoming &&
          next.status == VoiceCallStatus.connected;
      if (next.status == VoiceCallStatus.idle || answered) _close(context);
    });

    final call = ref.watch(voiceCallProvider);
    final notifier = ref.read(voiceCallProvider.notifier);
    final connected = call.status == VoiceCallStatus.connected;
    final statusText = switch (call.status) {
      VoiceCallStatus.incoming => 'Panggilan masuk…',
      VoiceCallStatus.dialing => 'Menghubungkan…',
      VoiceCallStatus.ringing => 'Memanggil…',
      VoiceCallStatus.connected when !call.audioConnected =>
        '${formatCallDuration(call.duration)} · menyambungkan suara…',
      VoiceCallStatus.connected => formatCallDuration(call.duration),
      VoiceCallStatus.ended => call.errorMessage ?? 'Panggilan berakhir',
      VoiceCallStatus.idle => 'Panggilan berakhir',
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.phone_in_talk_rounded,
                  size: 16,
                  color: AppColors.callAccent,
                ),
                SizedBox(width: 8),
                Text(
                  'PANGGILAN SUARA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.callAccent,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              width: 128,
              height: 128,
              decoration: const BoxDecoration(
                color: AppColors.callSurfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 68,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              call.displayName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (call.peerName.isNotEmpty && call.peerRole.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                call.peerRole,
                style: const TextStyle(fontSize: 13, color: Colors.white54),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: connected ? AppColors.callAccent : Colors.white70,
              ),
            ),
            const Spacer(),
            if (call.status == VoiceCallStatus.incoming)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundButton(
                    label: 'Tolak',
                    icon: Icons.call_end_rounded,
                    color: AppColors.ambulance,
                    onPressed: notifier.decline,
                  ),
                  _RoundButton(
                    label: 'Jawab',
                    icon: Icons.call_rounded,
                    color: AppColors.success,
                    onPressed: notifier.accept,
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ToggleButton(
                    icon: call.isMuted
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                    label: call.isMuted ? 'Bisu' : 'Mikrofon',
                    isActive: call.isMuted,
                    onPressed: connected ? notifier.toggleMute : null,
                  ),
                  _RoundButton(
                    label: 'Tutup',
                    icon: Icons.call_end_rounded,
                    color: AppColors.ambulance,
                    onPressed: call.isActive ? notifier.endCall : null,
                  ),
                  _ToggleButton(
                    icon: call.isSpeaker
                        ? Icons.volume_up_rounded
                        : Icons.volume_down_rounded,
                    label: call.isSpeaker ? 'Speaker' : 'Earpiece',
                    isActive: call.isSpeaker,
                    onPressed: connected ? notifier.toggleSpeaker : null,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact bar on the driver's trip sheet while a call is dialing or
/// connected, so navigation stays on screen.
class ActiveCallBar extends ConsumerWidget {
  const ActiveCallBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(voiceCallProvider);
    final onCall = call.isActive && call.status != VoiceCallStatus.incoming;
    if (!onCall) return const SizedBox.shrink();

    final notifier = ref.read(voiceCallProvider.notifier);
    final connected = call.status == VoiceCallStatus.connected;

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
                    call.displayName,
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
                        ? formatCallDuration(call.duration)
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
                onPressed: notifier.toggleMute,
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
                onPressed: notifier.toggleSpeaker,
              ),
              const SizedBox(width: 4),
            ],
            Material(
              color: AppColors.ambulance,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: notifier.endCall,
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

String formatCallDuration(Duration d) {
  final minutes = d.inMinutes.toString().padLeft(2, '0');
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: isActive ? Colors.white : AppColors.callSurfaceLight,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(
                icon,
                color: isActive ? AppColors.callSurface : Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: onPressed == null ? color.withValues(alpha: 0.5) : color,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}
