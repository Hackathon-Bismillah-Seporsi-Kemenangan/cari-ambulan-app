import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';

/// "Hubungi …": a free in-app voice call, or the phone's dialer when the
/// other side has a number.
Future<void> showCallOptions(
  BuildContext context, {
  required String name,
  required String? phone,
  required VoidCallback onInternetCall,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hubungi $name',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _Option(
              icon: Icons.phone_in_talk_rounded,
              color: AppColors.primary,
              background: AppColors.primarySurface,
              title: 'Panggilan internet',
              subtitle: 'Gratis, langsung di aplikasi',
              onTap: () {
                Navigator.pop(sheetContext);
                onInternetCall();
              },
            ),
            if (phone != null && phone.isNotEmpty) ...[
              const Divider(height: 1),
              _Option(
                icon: Icons.phone_rounded,
                color: AppColors.success,
                background: AppColors.successSurface,
                title: 'Panggilan seluler',
                subtitle: phone,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final opened = await launchUrl(
                    Uri(scheme: 'tel', path: phone),
                  );
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tidak dapat membuka aplikasi telepon.'),
                      ),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
