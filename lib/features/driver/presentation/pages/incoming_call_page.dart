import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/alerts/emergency_alert.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/dispatch_offer_model.dart';
import '../providers/driver_home_provider.dart';
import '../providers/driver_offer_provider.dart';
import '../providers/driver_trip_provider.dart';
import '../widgets/call_countdown.dart';

/// Full-screen "Panggilan Darurat" shown when an emergency order is offered.
///
/// Rings until the driver answers, and closes itself once the offer is gone:
/// accepted, declined or expired.
class IncomingCallPage extends ConsumerStatefulWidget {
  const IncomingCallPage({super.key, required this.offer});

  final DispatchOfferModel offer;

  static Future<void> open(BuildContext context, DispatchOfferModel offer) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => IncomingCallPage(offer: offer),
        ),
      );

  @override
  ConsumerState<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends ConsumerState<IncomingCallPage> {
  Timer? _hapticTimer;
  bool _isClosed = false;

  /// Seconds left when the page opened, for the countdown ring.
  late final Duration _remaining = Duration(
    seconds: ref.read(driverOfferProvider).remainingSeconds,
  );

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

  /// Siren, vibration and a notification until the driver responds.
  Future<void> _startAlert() async {
    final offer = widget.offer;
    final vibrating = await EmergencyAlert.start(
      title: 'Panggilan Darurat',
      body: [
        if (offer.requestCode.isNotEmpty) 'Order #${offer.requestCode}',
        offer.emergencyType ?? 'Darurat Medis',
        '${offer.distanceKm.toStringAsFixed(1)} km',
      ].join(' · '),
    );
    // No vibrator API: tap the haptic engine instead.
    if (!vibrating && mounted && !_isClosed) {
      HapticFeedback.heavyImpact();
      _hapticTimer = Timer.periodic(
        const Duration(milliseconds: 1500),
        (_) => HapticFeedback.heavyImpact(),
      );
    }
  }

  void _stopAlert() {
    _hapticTimer?.cancel();
    _hapticTimer = null;
    EmergencyAlert.stop();
  }

  void _close() {
    if (_isClosed || !mounted) return;
    _isClosed = true;
    _stopAlert();
    Navigator.of(context).pop();
  }

  Future<void> _accept() async {
    _stopAlert();
    // The page closes as soon as the offer is cleared, so keep what's needed
    // to start the trip afterwards.
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final offers = container.read(driverOfferProvider.notifier);

    final trip = await offers.accept();
    if (trip != null) {
      container.read(driverTripProvider.notifier).setTrip(trip);
      // Refresh the profile, now busy.
      container.invalidate(driverHomeProvider);
      return;
    }

    final error = container.read(driverOfferProvider).error;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error ?? 'Order sudah tidak tersedia atau koneksi bermasalah.',
        ),
      ),
    );
    // Taken by another driver or cancelled: drop the call.
    await offers.decline();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DriverOfferState>(driverOfferProvider, (_, next) {
      if (!next.hasOffer || next.offer?.id != widget.offer.id) _close();
    });

    final isResponding = ref.watch(
      driverOfferProvider.select((state) => state.isResponding),
    );
    final offer = widget.offer;

    return PopScope(
      // The driver must answer; back would silently drop the call.
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.ambulanceDark,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.ambulance, AppColors.ambulanceDark],
                stops: [0, 0.45],
              ),
            ),
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: _Header(
                    remaining: _remaining,
                    total: offer.offerWindow,
                  ),
                ),
                Expanded(
                  child: _DetailsCard(
                    offer: offer,
                    isResponding: isResponding,
                    onAccept: _accept,
                    onDecline: () =>
                        ref.read(driverOfferProvider.notifier).decline(),
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
  const _Header({required this.remaining, required this.total});

  final Duration remaining;
  final Duration total;

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
              Flexible(
                child: Text(
                  'PANGGILAN DARURAT',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          CallCountdown(remaining: remaining, total: total),
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
    required this.offer,
    required this.isResponding,
    required this.onAccept,
    required this.onDecline,
  });

  final DispatchOfferModel offer;
  final bool isResponding;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final notes = offer.patientNotes;
    final eta = offer.etaMinutes;

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
                        label: offer.emergencyType ?? 'Darurat Medis',
                        foreground: Colors.white,
                        background: AppColors.ambulance,
                      ),
                      _Pill(
                        icon: Icons.person_outline_rounded,
                        label: offer.patientName,
                        foreground: AppColors.textPrimary,
                        background: AppColors.background,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PickupRow(address: offer.pickupAddress),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.route_rounded,
                          label: 'Jarak',
                          value: '${offer.distanceKm.toStringAsFixed(1)} km',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.schedule_rounded,
                          label: 'ETA',
                          value: eta == null ? '–' : '$eta menit',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.local_hospital_outlined,
                          label: 'RS terdekat',
                          value: offer.nearestHospitalName ?? '–',
                        ),
                      ),
                    ],
                  ),
                  if (offer.bloodType != null) ...[
                    const SizedBox(height: 12),
                    _MedicalIdRow(bloodType: offer.bloodType!),
                  ],
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _NoteBox(note: notes),
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
                    onPressed: isResponding ? null : onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      disabledBackgroundColor: AppColors.success.withValues(
                        alpha: 0.6,
                      ),
                      disabledForegroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(60),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: isResponding
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
                    onPressed: isResponding ? null : onDecline,
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
  const _PickupRow({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.primarySurface,
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
              const Text(
                'Lokasi jemput',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
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
  const _MedicalIdRow({required this.bloodType});

  final String bloodType;

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
            color: AppColors.ambulance,
          ),
          const SizedBox(width: 8),
          const Text(
            'Golongan darah',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            bloodType,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
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
        color: AppColors.warningSurface,
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
