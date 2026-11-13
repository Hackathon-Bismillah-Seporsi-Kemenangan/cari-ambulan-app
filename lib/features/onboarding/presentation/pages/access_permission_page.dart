import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/user_role.dart';
import '../../../../core/permissions/access_permissions.dart';
import '../../../../core/theme/app_colors.dart';

/// After the introduction: "Izinkan akses agar bantuan cepat sampai" for
/// patients (location), "Izin wajib untuk driver" for drivers (location and
/// notifications). Each switch shows whether Android granted that
/// permission; tapping it asks. The main button asks for what is missing,
/// then moves on either way: the home screens ask again when needed.
class AccessPermissionPage extends ConsumerStatefulWidget {
  const AccessPermissionPage({
    super.key,
    required this.role,
    required this.onDone,
  });

  final UserRole role;
  final VoidCallback onDone;

  @override
  ConsumerState<AccessPermissionPage> createState() =>
      _AccessPermissionPageState();
}

class _AccessPermissionPageState extends ConsumerState<AccessPermissionPage> {
  bool _location = false;
  bool _notifications = false;
  bool _asking = false;

  AccessPermissions get _permissions => ref.read(accessPermissionsProvider);

  bool get _isDriver => widget.role.isDriver;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final (location, notifications) = await (
      _permissions.hasLocation(),
      _permissions.hasNotifications(),
    ).wait;
    if (!mounted) return;
    setState(() {
      _location = location;
      _notifications = notifications;
    });
  }

  Future<void> _ask(Future<bool> Function() request) async {
    if (_asking) return;
    setState(() => _asking = true);
    await request();
    await _refresh();
    if (mounted) setState(() => _asking = false);
  }

  Future<void> _allowAndContinue() async {
    if (_asking) return;
    setState(() => _asking = true);
    // One at a time: Android shows a single permission dialog.
    if (!_location) await _permissions.requestLocation();
    if (_isDriver && !_notifications) {
      await _permissions.requestNotifications();
    }
    if (!mounted) return;
    setState(() => _asking = false);
    widget.onDone();
  }

  void _explain() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kenapa izin ini wajib?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Lokasi dipakai untuk mencarikan Anda pasien terdekat dan '
                'menunjukkan posisi ambulans kepada pasien selama Anda Online.'
                '\n\nNotifikasi membunyikan panggilan darurat yang masuk. '
                'Tanpa izin ini, order darurat bisa terlewat.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                  sliver: SliverList.list(
                    children: [
                      Text(
                        _isDriver
                            ? 'Izin wajib untuk driver'
                            : 'Izinkan akses agar bantuan cepat sampai',
                        style: TextStyle(
                          fontSize: 26,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isDriver
                            ? 'Tanpa izin ini, Anda tidak bisa Online dan order '
                                  'darurat tidak akan masuk.'
                            : 'Saat darurat, setiap detik berharga. Izin ini '
                                  'membantu kami bertindak lebih cepat.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _PermissionCard(
                        key: const ValueKey('permission_location'),
                        icon: _isDriver
                            ? Icons.near_me_outlined
                            : Icons.location_on_outlined,
                        tint: _isDriver
                            ? AppColors.primaryLight
                            : AppColors.emergencyLight,
                        iconColor: _isDriver
                            ? AppColors.primary
                            : AppColors.emergency,
                        accent: _isDriver
                            ? AppColors.primary
                            : AppColors.emergency,
                        title: 'Lokasi',
                        body: _isDriver
                            ? 'Posisi ambulans dibagikan ke pasien selama Anda '
                                  'Online.'
                            : 'Ambulans menemukan Anda dengan tepat.',
                        granted: _location,
                        onRequest: _asking
                            ? null
                            : () => _ask(_permissions.requestLocation),
                      ),
                      if (_isDriver) ...[
                        const SizedBox(height: 12),
                        _PermissionCard(
                          key: const ValueKey('permission_notifications'),
                          icon: Icons.notifications_active_outlined,
                          tint: AppColors.emergencyLight,
                          iconColor: AppColors.emergency,
                          title: 'Notifikasi order',
                          body:
                              'Bunyi keras agar order darurat tidak terlewat.',
                          granted: _notifications,
                          accent: AppColors.primary,
                          onRequest: _asking
                              ? null
                              : () => _ask(_permissions.requestNotifications),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Data hanya dipakai saat layanan aktif. Ubah '
                              'kapan saja di Pengaturan.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: _asking ? null : _allowAndContinue,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          // Not FilledButton.icon: its label can't wrap
                          // with large text.
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_rounded, size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _isDriver
                                      ? 'Izinkan & Lanjut'
                                      : 'Izinkan Semua',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isDriver ? _explain : widget.onDone,
                          style: TextButton.styleFrom(
                            foregroundColor: _isDriver
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(
                            _isDriver ? 'Kenapa izin ini wajib?' : 'Atur nanti',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    super.key,
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.granted,
    required this.accent,
    required this.onRequest,
  });

  /// Border once granted.
  final Color accent;

  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String title;
  final String body;
  final bool granted;

  /// Null while another request is open.
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
    // A granted permission can only be taken back in Android's settings.
    final onTap = granted ? null : onRequest;
    return Semantics(
      toggled: granted,
      label: '$title, wajib',
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: granted ? accent : const Color(0xFFE2E8F0),
            width: granted ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const _RequiredBadge(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ExcludeSemantics(
                  child: Switch(
                    value: granted,
                    activeTrackColor: AppColors.online,
                    // Kept enabled so a granted switch stays green.
                    onChanged: onRequest == null ? null : (_) => onTap?.call(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequiredBadge extends StatelessWidget {
  const _RequiredBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Wajib',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
