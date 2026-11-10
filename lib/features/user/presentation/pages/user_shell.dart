import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../emergency/domain/emergency_models.dart';
import '../../../emergency/presentation/providers/emergency_provider.dart';
import '../../../emergency/presentation/widgets/ambulance_tracking_view.dart';
import '../../../emergency/presentation/widgets/searching_ambulance_view.dart';
import '../../../emergency/presentation/widgets/sos_button.dart';

class UserShell extends ConsumerWidget {
  const UserShell({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tell the user how a request ended when it wasn't their own cancel.
    ref.listen<EmergencyState>(emergencyProvider, (_, next) {
      if (next case EmergencyInitial(:final closed?)) {
        final hospital = closed.hospital?.name;
        final message = closed.status != EmergencyRequestStatus.completed
            ? 'Pesanan ambulans dibatalkan.'
            : hospital == null
                ? 'Pasien telah diserahkan ke IGD. Semoga lekas sembuh!'
                : 'Pasien telah diserahkan ke IGD $hospital. '
                    'Semoga lekas sembuh!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });

    final emergencyState = ref.watch(emergencyProvider);

    // An open request takes the whole screen: the search, then the
    // ambulance live on the map.
    if (emergencyState case EmergencyActive(:final request)) {
      return request.status.isSearching
          ? SearchingAmbulanceView(request: request)
          : AmbulanceTrackingView(request: request);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('CariAmbulan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Keluar Akun',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (emergencyState) {
          EmergencyLoading(:final message) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    message ?? 'Memproses...',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          // Shown full screen above.
          EmergencyActive() => const SizedBox.shrink(),
          EmergencyError(:final message) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          ref.read(emergencyProvider.notifier).checkActiveRequest(),
                      child: const Text('Kembali ke Beranda'),
                    ),
                  ],
                ),
              ),
            ),
          EmergencyInitial() => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // Greeting & Emergency Hotline Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primaryLight,
                          child: Text(
                            user.fullName.isNotEmpty
                                ? user.fullName[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Halo, ${user.fullName}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Text(
                                'Pusat Tanggap Darurat Medis 119',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Giant SOS Button in Center
                  const SosButton(),

                  const SizedBox(height: 36),

                  // Emergency Info Tip
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tekan tombol SOS di atas jika terjadi kegawatdaruratan medis. Sistem akan otomatis mendeteksi GPS Anda dan mengirimkan ambulans terdekat.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryDark,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        },
      ),
    );
  }
}
