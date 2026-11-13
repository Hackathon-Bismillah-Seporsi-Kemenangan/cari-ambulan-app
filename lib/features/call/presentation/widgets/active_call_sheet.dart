import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/call_models.dart';
import '../providers/voice_call_provider.dart';

class ActiveCallSheet extends ConsumerWidget {
  const ActiveCallSheet({super.key});

  static bool _open = false;

  /// Opens the call panel once: a push, the poll and the dial button can all
  /// ask for it for the same call. Full screen like a phone call, so it takes
  /// over a locked screen too.
  static void show(BuildContext context) {
    if (_open) return;
    _open = true;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.callSurface,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => const PopScope(
        canPop: false,
        child: Material(color: AppColors.callSurface, child: ActiveCallSheet()),
      ),
    ).whenComplete(() => _open = false);
  }

  /// Closes this call screen only, even if another page was pushed on top.
  static void _close(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route != null && route.isActive) {
      Navigator.of(context).removeRoute(route);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(voiceCallProvider);

    // Auto close bottom sheet when call ends
    ref.listen(voiceCallProvider, (previous, next) {
      // A driver who picked up leaves this screen for the bar on the trip
      // sheet: the map matters more than the call screen from here on.
      final isDriver = ref.read(authProvider).value?.isDriver ?? false;
      final driverPickedUp =
          isDriver &&
          previous?.status == VoiceCallStatus.incoming &&
          next.status == VoiceCallStatus.connected;
      if (next.status == VoiceCallStatus.idle || driverPickedUp) {
        _close(context);
      }
    });

    final notifier = ref.read(voiceCallProvider.notifier);
    final statusText = switch (call.status) {
      VoiceCallStatus.incoming => 'Panggilan masuk…',
      VoiceCallStatus.connected when !call.audioConnected =>
        '${_formatDuration(call.duration)} · menyambungkan suara…',
      VoiceCallStatus.dialing => 'Menghubungkan…',
      VoiceCallStatus.ringing => 'Memanggil ${call.peerName}…',
      VoiceCallStatus.connected => _formatDuration(call.duration),
      VoiceCallStatus.ended => call.errorMessage ?? 'Panggilan berakhir',
      VoiceCallStatus.idle => 'Selesai',
    };

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.callSurface,
      child: SafeArea(
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
                    'PANGGILAN SUARA LIVEKIT',
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
                child: Icon(
                  Icons.person_rounded,
                  size: 68,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                call.peerName.isEmpty ? call.peerRole : call.peerName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: call.status == VoiceCallStatus.connected
                      ? AppColors.callAccent
                      : Colors.white70,
                ),
              ),
              const Spacer(),
              if (call.status == VoiceCallStatus.incoming)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _EndCallButton(
                      label: 'Tolak',
                      onPressed: notifier.declineIncoming,
                    ),
                    _EndCallButton(
                      label: 'Jawab',
                      icon: Icons.call_rounded,
                      color: AppColors.online,
                      onPressed: notifier.acceptIncoming,
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallActionIcon(
                      icon: call.isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      label: call.isMuted ? 'Bisu' : 'Mikrofon',
                      isActive: call.isMuted,
                      onPressed: call.status == VoiceCallStatus.connected
                          ? () => ref
                                .read(voiceCallProvider.notifier)
                                .toggleMute()
                          : null,
                    ),
                    _EndCallButton(
                      onPressed: () {
                        ref.read(voiceCallProvider.notifier).endCall();
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    _CallActionIcon(
                      icon: call.isSpeaker
                          ? Icons.volume_up_rounded
                          : Icons.volume_down_rounded,
                      label: call.isSpeaker ? 'Speaker' : 'Earpiece',
                      isActive: call.isSpeaker,
                      onPressed: call.status == VoiceCallStatus.connected
                          ? () => ref
                                .read(voiceCallProvider.notifier)
                                .toggleSpeaker()
                          : null,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallActionIcon extends StatelessWidget {
  const _CallActionIcon({
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

class _EndCallButton extends StatelessWidget {
  const _EndCallButton({
    required this.onPressed,
    this.label = 'Tutup',
    this.icon = Icons.call_end_rounded,
    this.color = AppColors.emergency,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
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
