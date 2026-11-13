import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/driver_models.dart';

/// Bottom sheet on the driver home. Content switches with availability.
class DriverHomeSheet extends StatelessWidget {
  const DriverHomeSheet({
    super.key,
    required this.isOnline,
    required this.stats,
    required this.bottomInset,
  });

  final bool isOnline;
  final DriverTodayStats stats;

  /// Space reserved for the floating bottom nav.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + bottomInset),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isOnline
              ? _OnlineContent(key: const ValueKey('online'), stats: stats)
              : const _OfflineContent(key: ValueKey('offline')),
        ),
      ),
    );
  }
}

class _OfflineContent extends StatelessWidget {
  const _OfflineContent({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.power_settings_new_rounded,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Siap mulai bertugas?', style: text.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    'Anda belum menerima permintaan.',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Aktifkan sakelar Online di atas untuk mulai menerima permintaan '
          'darurat di sekitar Anda.',
          style: text.bodyMedium,
        ),
        const _SheetDivider(),
        Text('PASTIKAN SEBELUM ONLINE', style: text.labelSmall),
        const SizedBox(height: 12),
        const _InfoRow(
          icon: Icons.location_on_outlined,
          title: 'Akses lokasi',
          subtitle: 'Izinkan lokasi untuk menerima permintaan terdekat.',
        ),
        const SizedBox(height: 12),
        const _InfoRow(
          icon: Icons.notifications_active_outlined,
          title: 'Notifikasi & suara',
          subtitle: 'Aktifkan agar panggilan darurat tidak terlewat.',
        ),
      ],
    );
  }
}

class _OnlineContent extends StatelessWidget {
  const _OnlineContent({super.key, required this.stats});

  final DriverTodayStats stats;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'ONLINE · SIAP BERTUGAS',
              style: text.labelSmall?.copyWith(color: AppColors.online),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Menunggu permintaan\ndarurat di sekitar Anda',
          style: text.headlineSmall,
        ),
        const _SheetDivider(),
        const _InfoRow(
          icon: Icons.notifications_active_outlined,
          title: 'Panggilan masuk otomatis',
          subtitle:
              'Layar Panggilan Darurat terbuka otomatis dengan bunyi & getar.',
        ),
        const _SheetDivider(),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                value: '${stats.completedTrips}',
                label: 'Trip selesai',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                value: stats.rating?.toStringAsFixed(1) ?? '–',
                label: 'Rating',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: text.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: text.bodySmall),
        ],
      ),
    );
  }
}

class _SheetDivider extends StatelessWidget {
  const _SheetDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Divider(height: 1, color: AppColors.divider),
    );
  }
}
