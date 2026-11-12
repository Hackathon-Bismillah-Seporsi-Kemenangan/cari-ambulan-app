import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/medical_repository.dart';
import '../../domain/medical_profile.dart';
import '../providers/medical_profile_provider.dart';
import 'medical_id_form_page.dart';

/// "Medical ID": what paramedics see about the patient during an emergency.
class MedicalIdPage extends ConsumerWidget {
  const MedicalIdPage({super.key, this.inTab = false});

  /// Shown as a tab of the patient shell: no back button, and room for the
  /// floating tab bar.
  final bool inTab;

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const MedicalIdPage()));

  static Future<void> edit(BuildContext context, MedicalProfile profile) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MedicalIdFormPage(initial: profile),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medical = ref.watch(medicalProfileProvider);
    final name = ref.watch(authProvider).valueOrNull?.fullName ?? '';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: inTab
          ? null
          : AppBar(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
            ),
      body: SafeArea(
        bottom: false,
        child: switch (medical) {
          AsyncData(:final value) => RefreshIndicator(
            onRefresh: () => ref.refresh(medicalProfileProvider.future),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.paddingOf(context).bottom + (inTab ? 120 : 24),
              ),
              children: [
                _Header(onEdit: () => edit(context, value)),
                if (ref.watch(medicalSyncPendingProvider).valueOrNull ??
                    false) ...[
                  const SizedBox(height: 12),
                  const _SyncNotice(),
                ],
                const SizedBox(height: 20),
                _PatientCard(name: name, profile: value),
                const SizedBox(height: 24),
                _AllergiesAndConditions(
                  profile: value,
                  onAdd: () => edit(context, value),
                ),
                const SizedBox(height: 24),
                _EmergencyContactSection(
                  contact: value.emergencyContact,
                  onAdd: () => edit(context, value),
                ),
                const SizedBox(height: 20),
                _ShareOnSosTile(profile: value),
              ],
            ),
          ),
          AsyncError() => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(medicalProfileProvider),
              child: const Text('Gagal memuat Medical ID. Coba lagi'),
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// An edit made offline, still to be sent.
class _SyncNotice extends StatelessWidget {
  const _SyncNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 20, color: AppColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Perubahan tersimpan di HP ini dan belum tersinkron ke server. '
              'Tarik ke bawah untuk mencoba lagi.',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Medical ID',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Dibagikan ke paramedis saat darurat',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onEdit,
          tooltip: 'Ubah Medical ID',
          style: IconButton.styleFrom(backgroundColor: AppColors.background),
          icon: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

/// The red card: name, blood type, age, weight and height.
class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.name, required this.profile});

  final String name;
  final MedicalProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ambulance,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nama pasien',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  profile.bloodType ?? '?',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ambulance,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Stat(
                label: 'Usia',
                value: profile.age == null ? '–' : '${profile.age} th',
              ),
              const SizedBox(width: 10),
              _Stat(
                label: 'Berat',
                value: profile.weightKg == null
                    ? '–'
                    : '${profile.weightKg} kg',
              ),
              const SizedBox(width: 10),
              _Stat(
                label: 'Tinggi',
                value: profile.heightCm == null
                    ? '–'
                    : '${profile.heightCm} cm',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _AllergiesAndConditions extends StatelessWidget {
  const _AllergiesAndConditions({required this.profile, required this.onAdd});

  final MedicalProfile profile;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final allergy in profile.allergies)
        (icon: Icons.medication_outlined, label: allergy),
      for (final condition in profile.conditions)
        (icon: Icons.monitor_heart_outlined, label: condition),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Alergi & Kondisi'),
        const SizedBox(height: 10),
        if (items.isEmpty)
          _EmptyAction(
            text: 'Belum ada alergi atau kondisi tercatat',
            action: 'Tambah',
            onPressed: onAdd,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, size: 18, color: AppColors.textPrimary),
                      const SizedBox(width: 6),
                      Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _EmergencyContactSection extends StatelessWidget {
  const _EmergencyContactSection({required this.contact, required this.onAdd});

  final EmergencyContact? contact;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final contact = this.contact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Kontak Darurat'),
        const SizedBox(height: 10),
        if (contact == null)
          _EmptyAction(
            text: 'Belum ada kontak darurat',
            action: 'Tambah',
            onPressed: onAdd,
          )
        else ...[
          Text(
            contact.relation.isEmpty
                ? contact.name
                : '${contact.relation} — ${contact.name}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.divider, width: 1.5),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => launchUrl(Uri(scheme: 'tel', path: contact.phone)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        contact.phone,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.phone_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ShareOnSosTile extends ConsumerStatefulWidget {
  const _ShareOnSosTile({required this.profile});

  final MedicalProfile profile;

  @override
  ConsumerState<_ShareOnSosTile> createState() => _ShareOnSosTileState();
}

class _ShareOnSosTileState extends ConsumerState<_ShareOnSosTile> {
  bool _saving = false;

  Future<void> _toggle(bool value) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(medicalRepositoryProvider)
          .save(widget.profile.copyWith(shareOnSos: value));
      ref.invalidate(medicalProfileProvider);
    } on MedicalSavedOffline {
      // Kept on the phone; the page says it isn't synced yet.
      ref.invalidate(medicalProfileProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bagikan otomatis saat SOS',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Driver & RS tujuan menerima data ini',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: widget.profile.shareOnSos,
            onChanged: _saving ? null : _toggle,
            activeTrackColor: AppColors.success,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _EmptyAction extends StatelessWidget {
  const _EmptyAction({
    required this.text,
    required this.action,
    required this.onPressed,
  });

  final String text;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(onPressed: onPressed, child: Text('+ $action')),
        ],
      ),
    );
  }
}
