import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/emergency_models.dart';
import '../providers/emergency_provider.dart';

class AssignedDriverCard extends ConsumerWidget {
  const AssignedDriverCard({
    super.key,
    required this.request,
  });

  final EmergencyRequestModel request;

  int _currentStepIndex() {
    switch (request.status) {
      case EmergencyRequestStatus.driverAssigned:
        return 0;
      case EmergencyRequestStatus.enRouteToPickup:
        return 1;
      case EmergencyRequestStatus.arriveAtPickup:
        return 2;
      case EmergencyRequestStatus.enRouteToHospital:
        return 3;
      case EmergencyRequestStatus.completed:
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = request.assignedDriver;
    final ambulance = request.ambulance;
    final currentStep = _currentStepIndex();
    final isCompleted = request.status == EmergencyRequestStatus.completed;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status Header Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.blue.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCompleted ? Colors.blue.shade200 : Colors.green.shade200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.blue : Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted ? Icons.done_all : Icons.emergency,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.status.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? Colors.blue.shade800 : Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isCompleted
                            ? 'Pasien telah tiba & diserahterimakan di Rumah Sakit'
                            : 'Tim medis ambulans sedang merespons panggilan Anda',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Live Progress Stepper
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tahapan Perjalanan Ambulans',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                _buildStepRow(
                  index: 0,
                  currentStep: currentStep,
                  title: 'Ambulans Ditugaskan',
                  subtitle: 'Driver menerima panggilan',
                  isLast: false,
                ),
                _buildStepRow(
                  index: 1,
                  currentStep: currentStep,
                  title: 'Menuju Lokasi Pasien',
                  subtitle: 'Ambulans meluncur ke titik jemput',
                  isLast: false,
                ),
                _buildStepRow(
                  index: 2,
                  currentStep: currentStep,
                  title: 'Tiba di Lokasi Jemput',
                  subtitle: 'Tim medis melakukan penanganan awal',
                  isLast: false,
                ),
                _buildStepRow(
                  index: 3,
                  currentStep: currentStep,
                  title: 'Menuju Rumah Sakit',
                  subtitle: 'Evakuasi pasien ke IGD RS rujukan',
                  isLast: false,
                ),
                _buildStepRow(
                  index: 4,
                  currentStep: currentStep,
                  title: 'Tiba di IGD / Selesai',
                  subtitle: 'Serah terima medis selesai',
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Driver & Ambulance Info Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        (driver?.name.isNotEmpty ?? false)
                            ? driver!.name[0].toUpperCase()
                            : 'D',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver?.name ?? 'Pengemudi Ambulans',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No. SIM: ${driver?.licenseNumber ?? "–"}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.airport_shuttle, color: AppColors.ambulance, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ambulance?.plateNumber ?? 'Ambulans Kedaruratan',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            ambulance?.vehicleModel ?? ambulance?.ambulanceType ?? 'Ambulans ALS / Medis Lengkap',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lokasi Penjemputan',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          Text(
                            request.pickup.address,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Primary Action
          if (isCompleted) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    ref.read(emergencyProvider.notifier).checkActiveRequest(),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  'KEMBALI KE BERANDA',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Menghubungi nomor: ${driver?.phone ?? "021-119"}'),
                    ),
                  );
                },
                icon: const Icon(Icons.phone),
                label: const Text(
                  'HUBUNGI PENGEMUDI',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required int index,
    required int currentStep,
    required String title,
    required String subtitle,
    required bool isLast,
  }) {
    final isDone = currentStep > index;
    final isCurrent = currentStep == index;

    Color iconColor;
    IconData icon;

    if (isDone) {
      iconColor = Colors.green;
      icon = Icons.check_circle;
    } else if (isCurrent) {
      iconColor = AppColors.primary;
      icon = Icons.radio_button_checked;
    } else {
      iconColor = Colors.grey.shade400;
      icon = Icons.radio_button_unchecked;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(icon, size: 20, color: iconColor),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: isDone ? Colors.green : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              if (!isLast) const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }
}
