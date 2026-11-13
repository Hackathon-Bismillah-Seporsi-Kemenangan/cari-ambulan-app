import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/settings_list.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/user_repository.dart';
import '../../domain/user_models.dart';
import '../providers/user_home_providers.dart';
import '../widgets/sync_notice.dart';
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

/// "Profil": the account, emergency readiness, saved addresses, settings.
class UserProfilePage extends ConsumerWidget {
  const UserProfilePage({super.key, required this.onOpenMedicalId});

  final VoidCallback onOpenMedicalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final medical = ref.watch(medicalProfileProvider).value?.value;
    final addresses = ref.watch(savedAddressesProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(medicalProfileProvider)
            ..invalidate(_locationAlwaysProvider)
            ..invalidate(savedAddressesProvider);
          await ref.read(savedAddressesProvider.future);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            if (user != null) _AccountHeader(user: user),
            const SizedBox(height: 16),
            _ReadinessCard(
              medical: medical,
              hasHome: addresses.value?.value.isNotEmpty ?? false,
              onOpenMedicalId: onOpenMedicalId,
            ),
            const SizedBox(height: 22),
            _SectionHeader(
              title: 'Alamat tersimpan',
              action: '+ Tambah',
              onAction: () => _AddAddressSheet.show(context),
            ),
            const SizedBox(height: 8),
            _AddressList(addresses: addresses),
            const SizedBox(height: 22),
            const _SectionHeader(title: 'Akun & pengaturan'),
            const SizedBox(height: 8),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.people_outline_rounded,
                  label: 'Kontak darurat',
                  value: medical?.emergencyContact == null
                      ? 'Belum ada'
                      : '1 kontak',
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
                SettingsTile(
                  icon: Icons.notifications_active_outlined,
                  label: 'Notifikasi & suara darurat',
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
                  color: AppColors.emergency,
                  showChevron: false,
                  onTap: () => ref.read(authProvider.notifier).logout(),
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
                  color: AppColors.emergency,
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
          backgroundColor: AppColors.emergency,
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
  const _ReadinessCard({
    required this.medical,
    required this.hasHome,
    required this.onOpenMedicalId,
  });

  final MedicalProfile? medical;
  final bool hasHome;
  final VoidCallback onOpenMedicalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAlways = ref.watch(_locationAlwaysProvider).value ?? false;
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
      (
        done: hasHome,
        title: 'Simpan alamat rumah',
        subtitle: 'Lokasi jemput lebih cepat dipilih',
        action: 'Simpan',
        onTap: () => _AddAddressSheet.show(context),
      ),
    ];
    final doneCount = checks.where((c) => c.done).length;
    final next = checks.where((c) => !c.done).firstOrNull;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF7DFA0)),
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
                          ? AppColors.online
                          : const Color(0xFFF7DFA0),
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
  const _SectionHeader({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: Text(action!),
          ),
      ],
    );
  }
}

class _AddressList extends StatelessWidget {
  const _AddressList({required this.addresses});

  final AsyncValue<Synced<List<SavedAddress>>> addresses;

  @override
  Widget build(BuildContext context) {
    final value = addresses.value;
    if (value == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [
        if (!value.synced && value.value.isNotEmpty) ...[
          const SyncNotice(),
          const SizedBox(height: 8),
        ],
        SettingsGroup(
          children: [
            if (value.value.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Belum ada alamat tersimpan',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            for (final address in value.value)
              SettingsTile(
                icon: switch (address.label) {
                  'Rumah' => Icons.home_outlined,
                  'Kantor' => Icons.business_outlined,
                  _ => Icons.place_outlined,
                },
                label: address.label,
                subtitle: address.address,
                iconBackground: AppColors.primaryLight,
                iconColor: AppColors.primary,
              ),
          ],
        ),
      ],
    );
  }
}

/// Saves the current GPS position as "Rumah", "Kantor" or another label.
class _AddAddressSheet extends ConsumerStatefulWidget {
  const _AddAddressSheet();

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _AddAddressSheet(),
  );

  @override
  ConsumerState<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends ConsumerState<_AddAddressSheet> {
  static const _labels = ['Rumah', 'Kantor', 'Lainnya'];

  String _label = _labels.first;
  final _address = TextEditingController();
  bool _addressFilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final fix = ref.read(userLocationProvider).value;
    final address = _address.text.trim();
    if (fix == null || address.isEmpty) return;
    setState(() => _saving = true);
    final synced = await ref
        .read(userRepositoryProvider)
        .addAddress(
          SavedAddress(label: _label, address: address, location: fix.point),
        );
    ref.invalidate(savedAddressesProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'Alamat tersimpan.'
              : 'Alamat tersimpan di HP ini. Belum tersinkron ke server.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fix = ref.watch(userLocationProvider).value;
    final found = ref.watch(pickupAddressProvider).value;
    if (!_addressFilled && found != null) {
      _addressFilled = true;
      _address.text = found;
    }

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
            'Simpan lokasi saat ini',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            fix == null
                ? 'Mencari lokasi GPS…'
                : 'Titik GPS Anda sekarang akan disimpan.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final label in _labels)
                ChoiceChip(
                  label: Text(label),
                  selected: _label == label,
                  onSelected: (_) => setState(() => _label = label),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'Alamat'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: fix == null || _saving ? null : _save,
              child: const Text('Simpan'),
            ),
          ),
        ],
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
          .updateProfile(
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
              roles: user.roles,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ApiException && e.statusCode != 404
            ? e.message
            : 'Mengubah profil belum didukung server.';
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
            Text(_error!, style: const TextStyle(color: AppColors.emergency)),
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
