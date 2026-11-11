import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../call/presentation/providers/voice_call_provider.dart';
import '../../../call/presentation/widgets/call_options_sheet.dart';
import '../../../emergency/domain/emergency_models.dart';
import '../../data/routing_repository.dart';
import '../../domain/route_models.dart';
import '../providers/driver_trip_provider.dart';
import '../widgets/maneuver_banner.dart';
import '../widgets/trip_map_layout.dart';

/// "Menuju pasien": route from the driver to the pickup, then the
/// arrival step before leaving for the hospital.
class ToPatientPage extends ConsumerStatefulWidget {
  const ToPatientPage({super.key, required this.trip, required this.location});

  final EmergencyRequestModel trip;
  final LatLng location;

  @override
  ConsumerState<ToPatientPage> createState() => _ToPatientPageState();
}

class _ToPatientPageState extends ConsumerState<ToPatientPage>
    with StableRouteOrigin {
  void _callPatient(EmergencyRequestModel trip) {
    final name = trip.reporterName ?? 'Pasien';
    showCallOptions(
      context,
      name: name,
      phone: trip.reporterPhone,
      onInternetCall: () => ref.read(voiceCallProvider.notifier).startCall(
            requestId: trip.id,
            peerName: name,
            peerRole: 'Pasien / Keluarga',
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final isUpdating = ref.watch(
      driverTripProvider.select((state) => state.isUpdating),
    );
    final hasArrived = trip.status == EmergencyRequestStatus.arriveAtPickup;
    final pickup = LatLng(trip.pickup.latitude, trip.pickup.longitude);
    final route = ref
        .watch(
          routeProvider((from: routeOrigin(widget.location), to: pickup)),
        )
        .value;

    return TripMapLayout(
      location: widget.location,
      target: pickup,
      route: route,
      top: ManeuverBanner(route: route, arrived: hasArrived),
      sheet: TripSheet(
        children: [
          Text(
            hasArrived ? 'Tiba di lokasi pasien' : 'Menuju pasien',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _subtitle(trip, route, hasArrived),
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _PatientCard(
            trip: trip,
            distanceMeters: route?.distanceMeters,
            onCall: () => _callPatient(trip),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isUpdating
                ? null
                : () => ref.read(driverTripProvider.notifier).advanceStage(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor:
                  hasArrived ? AppColors.ambulance : AppColors.primary,
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
    );
  }

  String _subtitle(
    EmergencyRequestModel trip,
    DriveRoute? route,
    bool hasArrived,
  ) {
    if (hasArrived) return 'Temui pasien di ${trip.pickup.address}';
    if (route == null) return 'Menghitung rute…';
    final eta = formatClock(DateTime.now().add(route.duration));
    return 'Tiba $eta · ${formatDistance(route.distanceMeters)} tersisa';
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({
    required this.trip,
    required this.distanceMeters,
    required this.onCall,
  });

  final EmergencyRequestModel trip;
  final double? distanceMeters;

  final VoidCallback onCall;

  String get _name => trip.reporterName ?? 'Pasien Darurat';

  String get _initials => _name
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      trip.emergencyType ?? 'Darurat',
      if (trip.bloodType != null) 'Gol. darah ${trip.bloodType}',
    ].join(' · ');
    final distance = distanceMeters;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.ambulanceSurface,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: AppColors.ambulance,
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
                      _name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (distance != null)
                    Text(
                      formatDistance(distance),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  if (trip.isHighPriority) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.ambulanceSurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Prioritas Tinggi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ambulance,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (trip.patientNotes != null && trip.patientNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Keluhan: ${trip.patientNotes}',
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCall,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              backgroundColor: AppColors.primarySurface,
              foregroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.call_rounded, size: 20),
            label: const Text('Telepon'),
          ),
        ],
      ),
    );
  }
}
