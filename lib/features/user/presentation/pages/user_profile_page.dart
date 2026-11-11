import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/settings_list.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/user_repository.dart';
import '../../domain/medical_profile.dart';
import '../providers/medical_profile_provider.dart';
import 'medical_id_page.dart';

/// Whether location is allowed "Selalu", so it keeps being sent while the
/// screen is locked.
final _locationAlwaysProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    return await Geolocator.checkPermission() == LocationPermission.always;
  } catch (_) {
    return false;
  }
});

/// Unfilled segments of the readiness bar.
const _readinessTrack = Color(0xFFF7DFA0);

/// "Profil": the account, emergency readiness and settings.
class UserProfilePage extends ConsumerWidget {
  const UserProfilePage({super.key, required this.onOpenMedicalId});

  final VoidCallback onOpenMedicalId;

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Anda perlu masuk lagi untuk memanggil ambulans dari aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.ambulance),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final medical = ref.watch(medicalProfileProvider).valueOrNull;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_locationAlwaysProvider);
          ref.invalidate(medicalProfileProvider);
          await ref
              .read(medicalProfileProvider.future)
              .then<void>((_) {}, onError: (Object _) {});
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            // Room for the floating tab bar.
            MediaQuery.paddingOf(context).bottom + 120,
          ),
          children: [
            if (user != null) _AccountHeader(user: user),
            const SizedBox(height: 16),
            _ReadinessCard(medical: medical, onOpenMedicalId: onOpenMedicalId),
            const SizedBox(height: 22),
            const _SectionHeader(title: 'Akun & pengaturan'),
            const SizedBox(height: 8),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.people_outline_rounded,
                  label: 'Kontak darurat',
                  value: medical?.emergencyContact?.name ?? 'Belum ada',
                  onTap: () => MedicalIdPage.edit(
                    context,
                    medical ?? MedicalProfile.empty,
                  ),
                ),
                SettingsTile(
                  icon: Icons.health_and_safety_outlined,
                  label: 'Asuransi',
                  value: medical?.insurance ?? 'Belum ada',
                  onTap: () => MedicalIdPage.edit(
                    context,
                    medical ?? MedicalProfile.empty,
                  ),
                ),
                const SettingsTile(
                  icon: Icons.notifications_active_outlined,
                  label: 'Notifikasi & izin lokasi',
                  onTap: Geolocator.openAppSettings,
                ),
                SettingsTile(
                  icon: Icons.support_outlined,
                  label: 'Pusat bantuan',
                  onTap: () => _showHelp(context),
                ),
                SettingsTile(
                  icon: Icons.logout_rounded,
                  label: 'Keluar',
                  color: AppColors.ambulance,
                  showChevron: false,
                  onTap: () => _logout(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void _showHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pusat bantuan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Dalam keadaan darurat dan aplikasi tidak bisa dipakai, '
                'telepon 119.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.phone_in_talk_outlined,
                  color: AppColors.ambulance,
                ),
                title: const Text('Telepon 119'),
                onTap: () => launchUrl(Uri(scheme: 'tel', path: '119')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountHeader extends ConsumerWidget {
  const _AccountHeader({required this.user});

  final AuthUser user;

  String get _initials => user.fullName
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.ambulance,
          child: Text(
            _initials,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
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
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.phone ?? user.email ?? '',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => _EditAccountSheet(user: user),
          ),
          tooltip: 'Ubah profil',
          style: IconButton.styleFrom(backgroundColor: AppColors.background),
          icon: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

/// "Kesiapan darurat · 3 dari 4" with the next thing to fix.
class _ReadinessCard extends ConsumerWidget {
  const _ReadinessCard({required this.medical, required this.onOpenMedicalId});

  final MedicalProfile? medical;
  final VoidCallback onOpenMedicalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAlways =
        ref.watch(_locationAlwaysProvider).valueOrNull ?? false;
    final medical = this.medical;

    final checks = [
      (
        done: medical?.bloodType != null,
        title: 'Lengkapi Medical ID',
        subtitle: 'Golongan darah & alergi membantu paramedis',
        action: 'Isi',
        onTap: onOpenMedicalId,
      ),
      (
        done: medical?.emergencyContact != null,
        title: 'Tambah kontak darurat',
        subtitle: 'Dihubungi saat Anda tidak bisa menjawab',
        action: 'Tambah',
        onTap: () =>
            MedicalIdPage.edit(context, medical ?? MedicalProfile.empty),
      ),
      (
        done: locationAlways,
        title: 'Aktifkan lokasi “Selalu”',
        subtitle: 'Agar lokasi tetap terkirim saat layar terkunci',
        action: 'Aktifkan',
        onTap: () async {
          await Geolocator.openAppSettings();
          ref.invalidate(_locationAlwaysProvider);
        },
      ),
    ];
    final doneCount = checks.where((c) => c.done).length;
    final next = checks.where((c) => !c.done).firstOrNull;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _readinessTrack),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: AppColors.warning,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Kesiapan darurat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$doneCount dari ${checks.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < checks.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: i < doneCount
                          ? AppColors.success
                          : _readinessTrack,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          next.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          next.subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: next.onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      shape: const StadiumBorder(),
                      // The theme's full-width size can't fit in a Row.
                      minimumSize: const Size(0, 40),
                    ),
                    child: Text(next.action),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _EditAccountSheet extends ConsumerStatefulWidget {
  const _EditAccountSheet({required this.user});

  final AuthUser user;

  @override
  ConsumerState<_EditAccountSheet> createState() => _EditAccountSheetState();
}

class _EditAccountSheetState extends ConsumerState<_EditAccountSheet> {
  late final _name = TextEditingController(text: widget.user.fullName);
  late final _phone = TextEditingController(text: widget.user.phone);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await ref
          .read(userRepositoryProvider)
          .updateAccount(
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
          );
      final user = widget.user;
      ref
          .read(authProvider.notifier)
          .updateUser(
            AuthUser(
              id: user.id,
              fullName: updated.fullName,
              email: user.email,
              phone: updated.phone,
              alamat: user.alamat,
              roles: user.roles,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ApiException
            ? e.message
            : 'Gagal menyimpan profil. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ubah profil',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama lengkap'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Nomor telepon'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.ambulance)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Simpan'),
            ),
          ),
        ],
      ),
    );
  }
}
