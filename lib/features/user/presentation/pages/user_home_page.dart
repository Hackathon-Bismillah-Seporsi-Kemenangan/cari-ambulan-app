import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/location/location_service.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../emergency/presentation/providers/emergency_provider.dart';
import '../../../emergency/presentation/widgets/sos_button.dart';
import '../providers/saved_addresses_provider.dart';
import '../widgets/medical_id_card.dart';

/// "Beranda": the SOS button and the Medical ID summary.
class UserHomePage extends ConsumerWidget {
  const UserHomePage({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emergencyState = ref.watch(emergencyProvider);
    final savedPlaces = <SavedPlace>[
      for (final address
          in ref.watch(savedAddressesProvider).valueOrNull ?? const [])
        (label: address.label, location: address.location),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('CariAmbulan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
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
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Shown full screen by the shell.
          EmergencyActive() => const SizedBox.shrink(),
          EmergencyNoLocation() => _NoLocation(
            hasSavedPlaces: savedPlaces.isNotEmpty,
          ),
          EmergencyError(:final message) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref
                        .read(emergencyProvider.notifier)
                        .checkActiveRequest(),
                    child: const Text('Kembali ke Beranda'),
                  ),
                ],
              ),
            ),
          ),
          EmergencyInitial() => SingleChildScrollView(
            // Room for the floating tab bar.
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
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
                SosButton(savedPlaces: savedPlaces),

                const SizedBox(height: 36),

                const MedicalIdCard(),

                const SizedBox(height: 16),

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
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
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

/// SOS found no real position: turn location on, call 119, or go back and
/// pick a saved address.
class _NoLocation extends ConsumerWidget {
  const _NoLocation({required this.hasSavedPlaces});

  final bool hasSavedPlaces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 52,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            const Text(
              'Lokasi tidak ditemukan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ambulans belum dipanggil. Aktifkan lokasi (GPS) agar ambulans '
              'tahu ke mana harus datang'
              '${hasSavedPlaces ? ', atau pilih alamat tersimpan' : ''}. '
              'Jika kritis, segera telepon 119.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: '119')),
                icon: const Icon(Icons.phone_in_talk_outlined),
                label: const Text('Telepon 119'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () =>
                    ref.read(locationServiceProvider).openSettings(),
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Aktifkan lokasi'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () =>
                  ref.read(emergencyProvider.notifier).dismissNoLocation(),
              child: const Text('Kembali ke Beranda'),
            ),
          ],
        ),
      ),
    );
  }
}
