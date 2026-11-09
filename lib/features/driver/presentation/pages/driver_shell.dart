import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/location/location_service.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/driver_home_provider.dart';
import '../providers/driver_offer_provider.dart';
import '../providers/driver_trip_provider.dart';
import '../widgets/active_trip_card.dart';
import '../widgets/availability_card.dart';
import '../widgets/driver_location_card.dart';
import '../widgets/incoming_call_dialog.dart';
import 'trip_navigation_page.dart';

class DriverShell extends ConsumerWidget {
  const DriverShell({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<DriverHomeState>>(driverHomeProvider, (prev, next) {
      final isOnline = next.value?.profile.isOnline ?? false;
      final wasOnline = prev?.value?.profile.isOnline ?? false;
      if (isOnline && !wasOnline) {
        ref.read(driverOfferProvider.notifier).startPolling();
      } else if (!isOnline && wasOnline) {
        ref.read(driverOfferProvider.notifier).stopPolling();
      }
    });

    // Open navigation when a trip starts: just accepted, or resumed after
    // the app was closed mid-trip.
    ref.listen<DriverTripState>(driverTripProvider, (prev, next) {
      if (!(prev?.hasActiveTrip ?? false) && next.hasActiveTrip) {
        TripNavigationPage.open(context);
      }
    });

    final driverState = ref.watch(driverHomeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Portal Driver Ambulans'),
        backgroundColor: AppColors.ambulance,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: driverState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat profil driver: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(driverHomeProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (state) {
          final profile = state.profile;

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async => ref.invalidate(driverHomeProvider),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  // Driver Info Header
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
                          radius: 28,
                          backgroundColor: AppColors.ambulanceLight,
                          child: Text(
                            user.fullName.isNotEmpty
                                ? user.fullName[0].toUpperCase()
                                : 'D',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
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
                                user.fullName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'SIM: ${profile.licenseNumber ?? "–"}',
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
                  ),
                  const SizedBox(height: 16),

                  // Driver position on the map
                  DriverLocationCard(
                    location: LatLng(
                      state.lastBeaconLatitude ?? LocationService.defaultLatitude,
                      state.lastBeaconLongitude ?? LocationService.defaultLongitude,
                    ),
                    isOnline: profile.isOnline,
                  ),

                  // Active Emergency Trip Card (if driver is currently serving one)
                  const ActiveTripCard(),

                  // Availability Card (Online / Offline Toggle)
                  AvailabilityCard(
                    profile: profile,
                    isUpdating: state.isUpdating,
                    lastBeaconLat: state.lastBeaconLatitude,
                    lastBeaconLng: state.lastBeaconLongitude,
                    onToggle: () {
                      ref.read(driverHomeProvider.notifier).toggleAvailability();
                    },
                  ),

                  // Error notification if toggle fails
                  if (state.error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, color: AppColors.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.error!,
                              style: const TextStyle(color: AppColors.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Instructions Card
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.divider),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text(
                                'Petunjuk Pengemudi',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            profile.isOnline
                                ? '• Anda sedang ONLINE. Aplikasi akan memantau panggilan darurat baru.\n• Pastikan koneksi internet dan GPS tetap aktif.'
                                : '• Geser tombol di atas ke posisi ON jika Anda telah siap menerima tugas kedaruratan.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const IncomingCallDialog(),
        ],
      );
    },
      ),
    );
  }
}
