import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/driver_models.dart';

class AvailabilityCard extends StatelessWidget {
  const AvailabilityCard({
    super.key,
    required this.profile,
    required this.isUpdating,
    required this.onToggle,
  });

  final DriverProfile profile;
  final bool isUpdating;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isOnline = profile.isOnline;
    final statusColor = isOnline ? AppColors.success : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline ? AppColors.success.withValues(alpha: 0.5) : AppColors.divider,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Status indicator + Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOnline ? 'SIAP BERTUGAS (ONLINE)' : 'TIDAK AKTIF (OFFLINE)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              isUpdating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Switch.adaptive(
                      value: isOnline,
                      onChanged: (_) => onToggle(),
                      activeTrackColor: AppColors.success,
                    ),
            ],
          ),
          const SizedBox(height: 14),

          const Divider(height: 1),
          const SizedBox(height: 14),

          // Vehicle & Hospital Info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.airport_shuttle_rounded,
                  color: isOnline ? AppColors.success : AppColors.textSecondary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile.vehiclePlate} · ${profile.vehicleType}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.hospitalName ?? 'Belum Ditugaskan',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
