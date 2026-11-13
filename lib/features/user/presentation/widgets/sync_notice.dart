import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Shown when data could only be read from or saved on the phone, e.g.
/// while the server has no endpoint for it yet.
class SyncNotice extends StatelessWidget {
  const SyncNotice({
    super.key,
    this.text = 'Tersimpan di HP ini, belum tersinkron ke server.',
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}
