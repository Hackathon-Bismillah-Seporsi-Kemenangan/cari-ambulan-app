import '../../../../core/network/api_client.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../call/presentation/providers/voice_call_provider.dart';
import '../../domain/driver_models.dart';
import '../../domain/route_models.dart';
import '../providers/driver_home_provider.dart';
import '../widgets/maneuver_banner.dart';
import '../widgets/trip_call_widgets.dart';
import '../widgets/trip_map_layout.dart';
import 'to_hospital_page.dart';

/// "Menuju pasien": route from the driver to the pickup after accepting.
class ToPatientPage extends ConsumerStatefulWidget {
  const ToPatientPage({super.key});

  @override
  ConsumerState<ToPatientPage> createState() => _ToPatientPageState();
}

class _ToPatientPageState extends ConsumerState<ToPatientPage>
    with StableRouteOrigin {
  bool _isBusy = false;

  Future<void> _call(EmergencyRequest request) async {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hubungi ${request.reporterName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_in_talk_rounded,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text(
                  'Panggilan Internet (Dalam Aplikasi)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Bebas pulsa via LiveKit suara langsung'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ref
                      .read(voiceCallProvider.notifier)
                      .startCall(
                        emergencyRequestId: request.id,
                        peerName: request.reporterName,
                        peerRole: 'Pasien / Keluarga',
                      );
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_rounded, color: Colors.green),
                ),
                title: const Text(
                  'Panggilan Seluler (Pulsa)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(request.reporterPhone),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final opened = await launchUrl(
                    Uri(scheme: 'tel', path: request.reporterPhone),
                  );
                  if (!opened && mounted) {
                    _showMessage('Tidak dapat membuka aplikasi telepon.');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Runs [action] with the main button showing progress.
  Future<bool> _run(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
      return true;
    } catch (e) {
      _showMessage(
        e is ApiException ? e.message : 'Gagal mengirim status. Coba lagi.',
      );
      // The order moved on without this app (e.g. the patient cancelled).
      if (e is ApiException && e.isConflict) {
        ref.read(driverHomeProvider.notifier).syncTrip();
      }
      return false;
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _arrive() =>
      _run(ref.read(driverHomeProvider.notifier).markArrivedAtPatient);

  Future<void> _startToHospital() async {
    final ok = await _run(
      ref.read(driverHomeProvider.notifier).startToHospital,
    );
    if (ok && mounted) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ToHospitalPage()),
      );
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverHomeProvider).value;
    final trip = state?.trip;
    if (state == null || trip == null) return const Scaffold();

    final request = trip.request;
    final hasArrived = trip.stage == TripStage.atPatient;
    final route = ref
        .watch(
          routeProvider((
            from: routeOrigin(state.location),
            to: request.pickupLocation,
          )),
        )
        .value;

    return PopScope(
      // An accepted order can't be abandoned by pressing back.
      canPop: false,
      child: Scaffold(
        body: TripCallOverlay(
          child: TripMapLayout(
            location: state.location,
            target: request.pickupLocation,
            route: route,
            showTargetDot: true,
            top: ManeuverBanner(route: route, arrived: hasArrived),
            sheet: TripSheet(
              children: [
                const ActiveCallBar(),
                Text(
                  hasArrived ? 'Tiba di lokasi pasien' : 'Menuju pasien',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle(request, route, hasArrived),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _PatientCard(
                  request: request,
                  distanceMeters: route?.distanceMeters,
                  onCall: () => _call(request),
                  onChat: () => _showMessage('Fitur chat segera hadir.'),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isBusy
                      ? null
                      : hasArrived
                      ? _startToHospital
                      : _arrive,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: hasArrived ? AppColors.emergency : null,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.6,
                    ),
                    disabledForegroundColor: Colors.white,
                  ),
                  icon: _isBusy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          hasArrived
                              ? Icons.local_hospital_outlined
                              : Icons.where_to_vote_outlined,
                        ),
                  label: Text(
                    hasArrived ? 'Mulai ke Rumah Sakit' : 'Saya Sudah Tiba',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(
    EmergencyRequest request,
    DriveRoute? route,
    bool hasArrived,
  ) {
    if (hasArrived) {
      return 'Temui pasien di ${request.pickupDetail ?? 'lokasi'}';
    }
    if (route == null) return 'Menghitung rute…';
    final eta = formatClock(DateTime.now().add(route.duration));
    return 'Tiba $eta · ${formatDistance(route.distanceMeters)} tersisa';
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({
    required this.request,
    required this.distanceMeters,
    required this.onCall,
    required this.onChat,
  });

  final EmergencyRequest request;
  final double? distanceMeters;
  final VoidCallback onCall;
  final VoidCallback onChat;

  String get _initials => request.reporterName
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      request.condition,
      if (request.bloodType != null) request.bloodType!,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.emergencyLight,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: AppColors.emergency,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.reporterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.help_outline_rounded,
                          size: 14,
                          color: AppColors.emergency,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatDistance(distanceMeters ?? request.distanceKm * 1000),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (request.isHighPriority) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emergencyLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Prioritas Tinggi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emergency,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCall,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 20),
                  label: const Text('Telepon'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onChat,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: AppColors.primary,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                  label: const Text('Chat'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
