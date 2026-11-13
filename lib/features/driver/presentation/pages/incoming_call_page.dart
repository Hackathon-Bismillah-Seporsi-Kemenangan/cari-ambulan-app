import '../../../../core/network/api_client.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/alerts/emergency_alert.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/driver_models.dart';
import '../widgets/call_countdown.dart';

/// Full-screen "Panggilan Darurat" shown when an emergency order is offered.
///
/// Pops with `true` once [onAccept] succeeds, or `false` after the driver
/// declines or the offer expires (which calls [onDecline]).
class IncomingCallPage extends StatefulWidget {
  const IncomingCallPage({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final EmergencyRequest request;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage> {
  Timer? _alertTimer;
  bool _isAccepting = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _startAlert();
  }

  @override
  void dispose() {
    _stopAlert();
    super.dispose();
  }

  /// Ringtone, vibration and a notification until the driver responds.
  Future<void> _startAlert() async {
    final request = widget.request;
    final vibrating = await EmergencyAlert.start(
      title: 'Panggilan Darurat',
      body: [
        if (request.code != null) 'Order #${request.code}',
        request.condition,
        '${request.distanceKm.toStringAsFixed(1)} km',
      ].join(' · '),
    );
    // No vibrator API: tap the haptic engine instead.
    if (!vibrating && mounted && !_isClosing && !_isAccepting) {
      HapticFeedback.heavyImpact();
      _alertTimer = Timer.periodic(
        const Duration(milliseconds: 1500),
        (_) => HapticFeedback.heavyImpact(),
      );
    }
  }

  void _stopAlert() {
    _alertTimer?.cancel();
    EmergencyAlert.stop();
  }

  Future<void> _accept() async {
    if (_isAccepting || _isClosing) return;
    _stopAlert();
    setState(() => _isAccepting = true);
    try {
      await widget.onAccept();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAccepting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException
                ? e.message
                : 'Order sudah tidak tersedia atau koneksi bermasalah.',
          ),
        ),
      );
      _close();
    }
  }

  Future<void> _close() async {
    if (_isClosing) return;
    _stopAlert();
    setState(() => _isClosing = true);
    await widget.onDecline();
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final isBusy = _isAccepting || _isClosing;

    return PopScope(
      // The driver must answer; back would silently drop the call.
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.emergencyDark,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.emergency, AppColors.emergencyDark],
                stops: [0, 0.45],
              ),
            ),
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: _Header(
                    request: request,
                    // No auto-decline while a response is in flight.
                    onExpired: isBusy ? null : _close,
                  ),
                ),
                Expanded(
                  child: _DetailsCard(
                    request: request,
                    isAccepting: _isAccepting,
                    isBusy: isBusy,
                    onAccept: _accept,
                    onDecline: _close,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.request, required this.onExpired});

  final EmergencyRequest request;
  final VoidCallback? onExpired;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.crisis_alert_rounded, color: Colors.white, size: 26),
              SizedBox(width: 10),
              Text(
                'PANGGILAN DARURAT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          CallCountdown(
            expiresAt: request.expiresAt,
            total: request.offerWindow,
            onExpired: onExpired,
          ),
          const SizedBox(height: 20),
          Text(
            'Pilih Terima untuk mengambil order.\n'
            'Jika waktu habis, permintaan otomatis dialihkan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.request,
    required this.isAccepting,
    required this.isBusy,
    required this.onAccept,
    required this.onDecline,
  });

  final EmergencyRequest request;
  final bool isAccepting;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final hasMedicalId = request.bloodType != null || request.allergy != null;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Pill(
                        icon: Icons.monitor_heart_outlined,
                        label: [
                          request.condition,
                          ?request.symptom,
                        ].join(' · '),
                        foreground: Colors.white,
                        background: AppColors.emergency,
                      ),
                      _Pill(
                        icon: Icons.person_outline_rounded,
                        label: '${request.patientCount} pasien',
                        foreground: AppColors.textPrimary,
                        background: AppColors.background,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PickupRow(request: request),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.route_rounded,
                          label: 'Jarak',
                          value: '${request.distanceKm.toStringAsFixed(1)} km',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.schedule_rounded,
                          label: 'ETA',
                          value: '${request.etaMinutes} menit',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.local_hospital_outlined,
                          label: 'RS terdekat',
                          value: request.nearestHospitalName,
                        ),
                      ),
                    ],
                  ),
                  if (hasMedicalId) ...[
                    const SizedBox(height: 12),
                    _MedicalIdRow(request: request),
                  ],
                  if (request.note != null) ...[
                    const SizedBox(height: 12),
                    _NoteBox(note: request.note!),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                children: [
                  FilledButton.icon(
                    onPressed: isBusy ? null : onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.online,
                      disabledBackgroundColor: AppColors.online.withValues(
                        alpha: 0.6,
                      ),
                      disabledForegroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(60),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: isAccepting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 26),
                    label: const Text('Terima'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Tolak'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupRow extends StatelessWidget {
  const _PickupRow({required this.request});

  final EmergencyRequest request;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.location_on_outlined,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lokasi jemput', style: text.bodySmall),
              const SizedBox(height: 2),
              Text(
                request.pickupAddress,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (request.pickupDetail != null) ...[
                const SizedBox(height: 2),
                Text(request.pickupDetail!, style: text.bodySmall),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicalIdRow extends StatelessWidget {
  const _MedicalIdRow({required this.request});

  final EmergencyRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.health_and_safety_outlined,
            size: 18,
            color: AppColors.emergency,
          ),
          const SizedBox(width: 8),
          const Text(
            'Medical ID',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (request.bloodType != null)
                    TextSpan(
                      text: request.bloodType,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  if (request.bloodType != null && request.allergy != null)
                    const TextSpan(
                      text: '  ·  ',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  if (request.allergy != null)
                    TextSpan(
                      text: request.allergy,
                      style: const TextStyle(color: AppColors.emergency),
                    ),
                ],
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chat_outlined, size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '“$note”',
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
