import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../emergency/domain/emergency_models.dart';
import '../pages/trip_navigation_page.dart';
import '../providers/driver_trip_provider.dart';

class ActiveTripCard extends ConsumerWidget {
  const ActiveTripCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripState = ref.watch(driverTripProvider);
    final trip = tripState.trip;

    if (!tripState.hasActiveTrip || trip == null) {
      return const SizedBox.shrink();
    }

    String actionButtonLabel;
    IconData actionButtonIcon;
    Color actionButtonColor;

    switch (trip.status) {
      case EmergencyRequestStatus.driverAssigned:
      case EmergencyRequestStatus.enRouteToPickup:
        actionButtonLabel = 'TIBA DI LOKASI JEMPUT';
        actionButtonIcon = Icons.place;
        actionButtonColor = Colors.orange.shade700;
        break;
      case EmergencyRequestStatus.arriveAtPickup:
        actionButtonLabel = 'BAWA PASIEN KE RUMAH SAKIT';
        actionButtonIcon = Icons.local_hospital;
        actionButtonColor = Colors.teal;
        break;
      case EmergencyRequestStatus.enRouteToHospital:
        actionButtonLabel = 'SELESAI DI IGD / RUMAH SAKIT';
        actionButtonIcon = Icons.check_circle;
        actionButtonColor = Colors.green;
        break;
      default:
        actionButtonLabel = 'LANJUTKAN';
        actionButtonIcon = Icons.arrow_forward;
        actionButtonColor = AppColors.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade100.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'TUGAS AKTIF',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trip.status.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                trip.requestCode,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Pickup Location Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, color: AppColors.error, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Alamat Titik Jemput',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trip.pickup.address,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (trip.patientNotes != null && trip.patientNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.notes, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Keluhan: ${trip.patientNotes}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: () => TripNavigationPage.open(context),
            icon: const Icon(Icons.map_outlined),
            label: const Text(
              'BUKA NAVIGASI',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Action Button to Advance Stage
          ElevatedButton.icon(
            onPressed: tripState.isUpdating
                ? null
                : () => ref.read(driverTripProvider.notifier).advanceStage(),
            icon: tripState.isUpdating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(actionButtonIcon),
            label: Text(
              actionButtonLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: actionButtonColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }
}

