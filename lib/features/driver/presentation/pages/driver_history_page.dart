import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/driver_models.dart';
import '../providers/driver_home_provider.dart';

/// The driver's finished orders, newest first.
final driverTripHistoryProvider =
    FutureProvider.autoDispose<List<DriverTripHistoryItem>>(
      (ref) => ref.watch(driverRepositoryProvider).fetchTripHistory(),
      // Show the error instead of a spinner while Riverpod retries: pull to
      // refresh and reopening the tab load it again.
      retry: (count, error) => null,
    );

/// "Riwayat": orders the driver completed or that were cancelled.
class DriverHistoryPage extends ConsumerWidget {
  const DriverHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(driverTripHistoryProvider);
    final bottom = MediaQuery.paddingOf(context).bottom + 120;

    // White like the patient tabs, so the grey groups and cards stand out.
    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(driverTripHistoryProvider.future),
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
                'Order yang sudah Anda tangani',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ...switch (history) {
                AsyncData(value: final items) when items.isEmpty => [
                  const _Empty(
                    icon: Icons.history_rounded,
                    text: 'Belum ada order selesai.',
                  ),
                ],
                AsyncData(value: final items) => [
                  _Summary(items: items),
                  const SizedBox(height: 16),
                  for (final item in items) ...[
                    _TripCard(item: item),
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
      ),
    );
  }
}

/// "5 selesai · 1 dibatalkan" over the list.
class _Summary extends StatelessWidget {
  const _Summary({required this.items});

  final List<DriverTripHistoryItem> items;

  @override
  Widget build(BuildContext context) {
    final completed = items.where((item) => item.isCompleted).length;
    final cancelled = items.where((item) => item.isCancelled).length;

    return Row(
      children: [
        Expanded(
          child: _Count(
            value: completed,
            label: 'Selesai',
            color: AppColors.online,
            background: AppColors.onlineLight,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Count(
            value: cancelled,
            label: 'Dibatalkan',
            color: AppColors.textSecondary,
            background: AppColors.offlineLight,
          ),
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.value,
    required this.label,
    required this.color,
    required this.background,
  });

  final int value;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.item});

  final DriverTripHistoryItem item;

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

  static String _clock(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  String get _date {
    final d = item.requestedAt;
    return '${d.day} ${_months[d.month - 1]} ${d.year} · ${_clock(d)}';
  }

  @override
  Widget build(BuildContext context) {
    final (statusText, statusColor, statusBackground) = item.isCancelled
        ? ('Dibatalkan', AppColors.textSecondary, AppColors.offlineLight)
        : ('Selesai', AppColors.online, AppColors.onlineLight);
    final endedAt = item.completedAt ?? item.cancelledAt;
    final outcome = item.isCancelled
        ? [
            'Dibatalkan pasien',
            if (endedAt != null) _clock(endedAt),
            ?item.cancelReason,
          ].join(' · ')
        : [
            ?item.hospitalName,
            if (endedAt != null) 'Diserahkan ${_clock(endedAt)}',
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
          if (item.patientName != null)
            _Line(icon: Icons.person_outline_rounded, text: item.patientName!),
          _Line(icon: Icons.location_on_outlined, text: item.pickupAddress),
          if (outcome.isNotEmpty)
            _Line(
              icon: item.isCancelled
                  ? Icons.cancel_outlined
                  : Icons.local_hospital_outlined,
              text: outcome,
              maxLines: 2,
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.maxLines = 1});

  final IconData icon;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
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
