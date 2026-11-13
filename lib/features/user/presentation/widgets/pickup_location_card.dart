import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// "Lokasi kamu · GPS ±10 m / Jl. Sudirman No. 21 / Ubah" at the top of the
/// home map.
class PickupLocationCard extends StatelessWidget {
  const PickupLocationCard({
    super.key,
    required this.address,
    required this.accuracyMeters,
    required this.onChange,
  });

  /// Null while the address is still loading.
  final String? address;

  /// Null when GPS is off and the app uses a fallback position.
  final double? accuracyMeters;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final gps = accuracyMeters == null
        ? 'GPS tidak aktif'
        : 'GPS ±${accuracyMeters!.round()} m';

    return Material(
      color: AppColors.surface,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_outlined,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lokasi kamu · $gps',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address ?? 'Mencari alamat…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onChange,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Ubah'),
            ),
          ],
        ),
      ),
    );
  }
}
