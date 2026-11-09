import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../emergency/domain/emergency_models.dart';
import '../../data/routing_repository.dart';
import '../providers/driver_trip_provider.dart';
import '../widgets/trip_map_layout.dart';
import '../widgets/trip_timeline.dart';

/// "Menuju rumah sakit": patient on board, driving to the assigned IGD.
class ToHospitalPage extends ConsumerStatefulWidget {
  const ToHospitalPage({
    super.key,
    required this.trip,
    required this.hospital,
    required this.location,
  });

  final EmergencyRequestModel trip;
  final HospitalInfo hospital;
  final LatLng location;

  @override
  ConsumerState<ToHospitalPage> createState() => _ToHospitalPageState();
}

class _ToHospitalPageState extends ConsumerState<ToHospitalPage>
    with StableRouteOrigin {
  Future<void> _handover() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Serahkan pasien?'),
        content: Text(
          'Pastikan pasien sudah diterima tim IGD '
          '${widget.hospital.name}. Order akan ditutup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, Serahkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(driverTripProvider.notifier).advanceStage();
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final hospital = widget.hospital;
    final isUpdating = ref.watch(
      driverTripProvider.select((state) => state.isUpdating),
    );
    final target = LatLng(hospital.latitude, hospital.longitude);
    final route = ref
        .watch(
          routeProvider((from: routeOrigin(widget.location), to: target)),
        )
        .value;
    final eta =
        route == null ? null : formatClock(DateTime.now().add(route.duration));

    return TripMapLayout(
      location: widget.location,
      target: target,
      route: route,
      top: _HospitalNotice(
        hospital: hospital,
        preparation: trip.hospitalPreparation,
      ),
      sheet: TripSheet(
        children: [
          const Text(
            'Menuju rumah sakit',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${hospital.name} · '
            '${eta == null ? 'Menghitung rute…' : 'ETA $eta'}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TripTimeline(entries: _timeline(trip, eta)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isUpdating ? null : _handover,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white,
            ),
            icon: isUpdating
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.local_hospital_outlined),
            label: const Text('Serahkan Pasien ke IGD'),
          ),
        ],
      ),
    );
  }

  List<TimelineEntry> _timeline(EmergencyRequestModel trip, String? eta) {
    String? at(DateTime? time) => time == null ? null : formatClock(time);
    const done = TimelineStatus.done;

    return [
      TimelineEntry(
        label: 'Panggilan diterima',
        status: done,
        caption: at(trip.acceptedAt),
      ),
      TimelineEntry(
        label: 'Tiba di lokasi',
        status: done,
        caption: at(trip.arrivedAtPickupAt),
      ),
      TimelineEntry(
        label: 'Menuju rumah sakit',
        status: TimelineStatus.active,
        caption: eta == null ? at(trip.pickedUpAt) : 'ETA $eta',
      ),
      const TimelineEntry(label: 'Selesai', status: TimelineStatus.pending),
    ];
  }
}

/// Yellow card confirming the hospital's IGD was alerted.
class _HospitalNotice extends StatelessWidget {
  const _HospitalNotice({required this.hospital, this.preparation});

  final HospitalInfo hospital;
  final String? preparation;

  @override
  Widget build(BuildContext context) {
    final entrance = hospital.ambulanceEntrance;
    final details = [
      if (preparation != null && preparation!.isNotEmpty) preparation!,
      if (entrance != null) 'Pintu masuk ambulans: $entrance.',
    ].join(' ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${hospital.name} sudah diberi tahu',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    details,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
