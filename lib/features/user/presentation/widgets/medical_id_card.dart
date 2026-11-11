import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/medical_profile.dart';
import '../pages/medical_id_page.dart';
import '../providers/medical_profile_provider.dart';

/// Medical ID summary on Beranda: blood type and emergency contact, or a
/// nudge to fill them in before an emergency.
class MedicalIdCard extends ConsumerWidget {
  const MedicalIdCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(medicalProfileProvider).valueOrNull;
    final complete = profile?.isComplete ?? false;

    return Material(
      color: complete ? AppColors.surface : AppColors.warningSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: complete
              ? AppColors.divider
              : AppColors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => MedicalIdPage.open(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: complete
                      ? AppColors.ambulanceSurface
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: complete
                    ? Text(
                        profile!.bloodType!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ambulance,
                        ),
                      )
                    : const Icon(
                        Icons.health_and_safety_outlined,
                        color: AppColors.warning,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complete ? 'Medical ID' : 'Lengkapi Medical ID',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(profile),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _subtitle(MedicalProfile? profile) {
    if (profile == null || !profile.isComplete) {
      return 'Golongan darah dan kontak darurat membantu paramedis '
          'menolong Anda lebih cepat.';
    }
    final contact = profile.emergencyContact!;
    return [
      if (profile.allergies.isNotEmpty)
        'Alergi: ${profile.allergies.join(', ')}',
      'Kontak: ${contact.name}',
    ].join(' · ');
  }
}
