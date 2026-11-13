import '../../../../core/network/api_client.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/driver_models.dart';
import '../providers/driver_home_provider.dart';
import '../widgets/trip_call_widgets.dart';
import '../widgets/trip_map_layout.dart';
import '../widgets/trip_timeline.dart';

/// "Menuju rumah sakit": patient on board, driving to the assigned IGD.
class ToHospitalPage extends ConsumerStatefulWidget {
  const ToHospitalPage({super.key});

  @override
  ConsumerState<ToHospitalPage> createState() => _ToHospitalPageState();
}

class _ToHospitalPageState extends ConsumerState<ToHospitalPage>
    with StableRouteOrigin {
  bool _isCompleting = false;

  /// Last trip shown, kept so the page doesn't go blank while it closes
  /// after handover clears the trip.
  ActiveTrip? _trip;

  Future<void> _handover(HospitalAssignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Serahkan pasien?'),
        content: Text(
          'Pastikan pasien sudah diterima tim IGD '
          '${assignment.hospital.name}. Order akan ditutup.',
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

    setState(() => _isCompleting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(driverHomeProvider.notifier).completeHandover();
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Order selesai. Anda kembali online. Terima kasih!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCompleting = false);
      if (e is ApiException && e.isConflict) {
        ref.read(driverHomeProvider.notifier).syncTrip();
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Gagal menutup order. Coba lagi.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverHomeProvider).value;
    final trip = _trip = state?.trip ?? _trip;
    final assignment = trip?.hospital;
    if (state == null || trip == null || assignment == null) {
      return const Scaffold();
    }

    final hospital = assignment.hospital;
    final route = ref
        .watch(
          routeProvider((
            from: routeOrigin(state.location),
            to: hospital.location,
          )),
        )
        .value;
    final eta = route == null
        ? null
        : formatClock(DateTime.now().add(route.duration));

    return PopScope(
      canPop: false,
      child: Scaffold(
        // The patient is on board; the reporter may still call for updates.
        body: TripCallOverlay(
          child: TripMapLayout(
            location: state.location,
            target: hospital.location,
            route: route,
            hospital: route == null
                ? hospital
                : NearbyHospital(
                    name: hospital.name,
                    location: hospital.location,
                    distanceKm: route.distanceMeters / 1000,
                  ),
            top: _HospitalNotice(assignment: assignment),
            sheet: TripSheet(
              children: [
                const ActiveCallBar(),
                Text(
                  'Menuju rumah sakit',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Pasien di dalam ambulans · '
                  '${eta == null ? 'Menghitung rute…' : 'ETA $eta'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TripTimeline(entries: _timeline(trip, eta)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isCompleting ? null : () => _handover(assignment),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.6,
                    ),
                    disabledForegroundColor: Colors.white,
                  ),
                  icon: _isCompleting
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
          ),
        ),
      ),
    );
  }

  List<TimelineEntry> _timeline(ActiveTrip trip, String? eta) {
    String? at(DateTime? time) => time == null ? null : formatClock(time);
    const done = TimelineStatus.done;

    return [
      TimelineEntry(
        label: 'Mencari ambulans',
        status: done,
        caption: at(trip.request.requestedAt ?? trip.request.offeredAt),
      ),
      TimelineEntry(
        label: 'Pesanan diterima',
        status: done,
        caption: at(trip.acceptedAt),
      ),
      // The driver sets off as soon as the order is accepted.
      TimelineEntry(
        label: 'Dalam perjalanan',
        status: done,
        caption: at(trip.acceptedAt),
      ),
      TimelineEntry(
        label: 'Tiba di lokasi',
        status: done,
        caption: at(trip.arrivedAt),
      ),
      TimelineEntry(
        label: 'Menuju rumah sakit',
        status: TimelineStatus.active,
        caption: eta == null ? null : 'ETA $eta',
      ),
      const TimelineEntry(label: 'Selesai', status: TimelineStatus.pending),
    ];
  }
}

/// Yellow card confirming the hospital's IGD was alerted.
class _HospitalNotice extends StatelessWidget {
  const _HospitalNotice({required this.assignment});

  final HospitalAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final entrance = assignment.entrance;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
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
                  '${assignment.hospital.name} sudah diberi tahu',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    assignment.preparation,
                    if (entrance != null) 'Pintu masuk ambulans: $entrance.',
                  ].join(' '),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
