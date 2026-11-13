import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/settings_list.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/driver_models.dart';
import '../providers/driver_home_provider.dart';

/// Whether location is allowed "Selalu", so dispatch keeps seeing the
/// ambulance while the screen is locked.
final _locationAlwaysProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    return await Geolocator.checkPermission() == LocationPermission.always;
  } catch (_) {
    return false;
  }
});

/// "Profil": the driver's account, ambulance, trip counts and settings.
class DriverProfilePage extends ConsumerWidget {
  const DriverProfilePage({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final home = ref.read(driverHomeProvider).value;
    if (home?.trip != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selesaikan order yang sedang berjalan sebelum keluar.',
          ),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Anda akan offline dan tidak menerima panggilan darurat sampai '
          'masuk lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.emergency),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // Stop receiving calls before the token is revoked.
    if (home != null && home.isOnline) {
      await ref
          .read(driverRepositoryProvider)
          .setAvailability(DriverAvailability.offline, home.location)
          .catchError((Object _) {});
    }
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final home = ref.watch(driverHomeProvider).value;
    final profile = home?.profile;
    final always = ref.watch(_locationAlwaysProvider).value;

    // White like the patient tabs, so the grey groups and cards stand out.
    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_locationAlwaysProvider);
            await ref
                .read(driverHomeProvider.notifier)
                .refreshProfile()
                .catchError((Object _) {});
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.paddingOf(context).bottom + 120,
            ),
            children: [
              if (user != null)
                _AccountHeader(user: user, isOnline: home?.isOnline ?? false),
              const SizedBox(height: 16),
              if (home != null) _Stats(stats: home.stats),
              const SizedBox(height: 22),
              const _SectionTitle('Kendaraan & tugas'),
              const SizedBox(height: 8),
              SettingsGroup(
                children: [
                  SettingsTile(
                    icon: Icons.airport_shuttle_outlined,
                    label: profile?.vehiclePlate ?? '–',
                    subtitle: profile?.vehicleType,
                    iconColor: AppColors.primary,
                  ),
                  SettingsTile(
                    icon: Icons.badge_outlined,
                    label: 'Nomor SIM',
                    value: profile?.licenseNumber ?? '–',
                  ),
                  SettingsTile(
                    icon: Icons.local_hospital_outlined,
                    label: 'Rumah sakit',
                    subtitle:
                        profile?.hospitalName ?? 'Tidak terikat rumah sakit',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _SectionTitle('Akun & pengaturan'),
              const SizedBox(height: 8),
              SettingsGroup(
                children: [
                  SettingsTile(
                    icon: Icons.notifications_active_outlined,
                    label: 'Notifikasi & suara panggilan',
                    onTap: Geolocator.openAppSettings,
                  ),
                  SettingsTile(
                    icon: Icons.my_location_rounded,
                    label: 'Izin lokasi',
                    value: switch (always) {
                      true => 'Selalu',
                      false => 'Saat dipakai',
                      null => null,
                    },
                    onTap: () async {
                      await Geolocator.openAppSettings();
                      ref.invalidate(_locationAlwaysProvider);
                    },
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
                    onTap: () => _logout(context, ref),
                  ),
                ],
              ),
            ],
          ),
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
                'Jika aplikasi bermasalah saat bertugas, hubungi rumah sakit '
                'atau telepon 119.',
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

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.user, required this.isOnline});

  final AuthUser user;
  final bool isOnline;

  String get _initials => user.fullName
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.primary,
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
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isOnline
                      ? AppColors.onlineLight
                      : AppColors.offlineLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isOnline
                        ? AppColors.online
                        : AppColors.textSecondary,
                  ),
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

/// "Hari ini" and "Total selesai" trip counts.
class _Stats extends StatelessWidget {
  const _Stats({required this.stats});

  final DriverTodayStats stats;

  @override
  Widget build(BuildContext context) {
    Widget tile(String value, String label) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
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
      ),
    );

    return Row(
      children: [
        tile('${stats.completedTrips}', 'Trip hari ini'),
        const SizedBox(width: 12),
        tile('${stats.totalCompletedTrips ?? '–'}', 'Total selesai'),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
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
          .read(driverRepositoryProvider)
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
