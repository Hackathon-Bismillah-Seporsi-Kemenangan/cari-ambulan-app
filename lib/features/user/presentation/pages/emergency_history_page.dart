import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/user_models.dart';
import '../providers/user_home_providers.dart';

/// "Riwayat": the user's past ambulance requests.
class EmergencyHistoryPage extends ConsumerWidget {
  const EmergencyHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(emergencyHistoryProvider);
    final bottom = MediaQuery.paddingOf(context).bottom + 24;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(emergencyHistoryProvider.future),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
          children: [
            const Text(
              'Riwayat',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Permintaan ambulans Anda sebelumnya',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ...switch (history) {
              AsyncData(value: final items) when items.isEmpty => [
                const _Empty(
                  icon: Icons.history_rounded,
                  text: 'Belum ada riwayat permintaan ambulans.',
                ),
              ],
              AsyncData(value: final items) => [
                for (final item in items) ...[
                  _HistoryCard(item: item),
                  const SizedBox(height: 12),
                ],
              ],
              AsyncError(:final error) => [
                _Empty(
                  icon: Icons.cloud_off_rounded,
                  text:
                      error is ApiException &&
                          (error.statusCode == 404 || error.statusCode == 405)
                      ? 'Riwayat belum tersedia di server.'
                      : 'Gagal memuat riwayat. Tarik ke bawah untuk mencoba '
                            'lagi.',
                ),
              ],
              _ => [
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            },
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final EmergencyHistoryItem item;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  String get _date {
    final d = item.requestedAt;
    final time =
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
    return '${d.day} ${_months[d.month - 1]} ${d.year} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final (statusText, statusColor, statusBackground) = item.isCancelled
        ? ('Dibatalkan', AppColors.textSecondary, AppColors.offlineLight)
        : item.isCompleted
        ? ('Selesai', AppColors.online, AppColors.onlineLight)
        : ('Berjalan', AppColors.emergency, AppColors.emergencyLight);
    final details = [
      ?item.hospitalName,
      ?item.plateNumber,
      ?item.driverName,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _date,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${item.emergencyType} · #${item.code}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.pickupAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.local_hospital_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
