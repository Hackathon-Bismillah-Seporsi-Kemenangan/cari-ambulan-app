import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/user_role.dart';
import '../../data/onboarding_repository.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';

const _kBlue = Color(0xFF1565C0);
const _kRed = Color(0xFFE53935);
const _kBorder = Color(0xFFE5E7EB);
const _kTextMuted = Color(0xFF6B7280);

/// Permission request page shown after onboarding slides.
/// Matches the exact design of the 4th/3rd slide in Figma.
class PermissionRequestPage extends StatefulWidget {
  final UserRole role;
  final OnboardingRepository repository;

  const PermissionRequestPage({
    super.key,
    required this.role,
    required this.repository,
  });

  @override
  State<PermissionRequestPage> createState() => _PermissionRequestPageState();
}

class _PermissionRequestPageState extends State<PermissionRequestPage> {
  // Initial states matching the design mockups
  late bool _locationEnabled;
  late bool _notifEnabled;
  bool _phoneEnabled = false;
  bool _cameraEnabled = false;

  @override
  void initState() {
    super.initState();
    // In Figma: Patient has Location ON, Notif OFF, Phone OFF.
    // Driver has Background Location ON, Order Notif ON, Phone OFF, Camera OFF.
    _locationEnabled = true;
    _notifEnabled = widget.role.isDriver;
  }

  void _proceedToDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, _, _) =>
            DashboardPage(role: widget.role, repository: widget.repository),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = widget.role.isDriver;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
            size: 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Title
                      Text(
                        isDriver
                            ? 'Izin wajib untuk driver'
                            : 'Izinkan akses agar\nbantuan cepat sampai',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Subtitle
                      Text(
                        isDriver
                            ? 'Tanpa izin ini, Anda tidak bisa Online dan order darurat tidak akan masuk.'
                            : 'Saat darurat, setiap detik berharga. Izin ini membantu kami bertindak lebih cepat.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: _kTextMuted,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Permission Cards
                      if (isDriver) ...[
                        _PermissionCard(
                          icon: Icons.near_me_outlined,
                          title: 'Lokasi latar belakang',
                          badge: 'Wajib',
                          badgeColor: _kBlue,
                          description:
                              'Posisi ambulans dibagikan ke pasien selama Anda Online.',
                          enabled: _locationEnabled,
                          accentColor: _kBlue,
                          onChanged: (v) =>
                              setState(() => _locationEnabled = v),
                        ),
                        const SizedBox(height: 12),
                        _PermissionCard(
                          icon: Icons.notifications_active_outlined,
                          title: 'Notifikasi order',
                          badge: 'Wajib',
                          badgeColor: _kBlue,
                          description:
                              'Bunyi keras & layar penuh agar order tidak terlewat.',
                          enabled: _notifEnabled,
                          accentColor: _kBlue,
                          onChanged: (v) => setState(() => _notifEnabled = v),
                        ),
                        const SizedBox(height: 12),
                        _PermissionCard(
                          icon: Icons.phone_outlined,
                          title: 'Telepon',
                          description: 'Hubungi pasien atau keluarga langsung.',
                          enabled: _phoneEnabled,
                          accentColor: _kBlue,
                          onChanged: (v) => setState(() => _phoneEnabled = v),
                        ),
                        const SizedBox(height: 12),
                        _PermissionCard(
                          icon: Icons.camera_alt_outlined,
                          title: 'Kamera',
                          description: 'Foto bukti serah terima pasien di IGD.',
                          enabled: _cameraEnabled,
                          accentColor: _kBlue,
                          onChanged: (v) => setState(() => _cameraEnabled = v),
                        ),
                      ] else ...[
                        _PermissionCard(
                          icon: Icons.location_on_outlined,
                          title: 'Lokasi',
                          badge: 'Wajib saat darurat',
                          badgeColor: _kRed,
                          description:
                              'Ambulans menemukan Anda dengan tepat, bahkan saat aplikasi tertutup.',
                          enabled: _locationEnabled,
                          accentColor: _kRed,
                          highlightBorder: true,
                          onChanged: (v) =>
                              setState(() => _locationEnabled = v),
                        ),
                        const SizedBox(height: 12),
                        _PermissionCard(
                          icon: Icons.notifications_none_rounded,
                          title: 'Notifikasi',
                          description:
                              'Kabar driver, posisi, dan waktu tiba langsung di layar.',
                          enabled: _notifEnabled,
                          accentColor: _kBlue,
                          onChanged: (v) => setState(() => _notifEnabled = v),
                        ),
                        const SizedBox(height: 12),
                        _PermissionCard(
                          icon: Icons.phone_outlined,
                          title: 'Telepon',
                          description:
                              'Driver & tim medis bisa menelepon Anda langsung.',
                          enabled: _phoneEnabled,
                          accentColor: _kBlue,
                          onChanged: (v) => setState(() => _phoneEnabled = v),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Privacy lock note
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 15,
                            color: _kTextMuted.withAlpha(200),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Data hanya dipakai saat layanan aktif. Ubah kapan saja di Pengaturan.',
                              style: TextStyle(
                                fontSize: 12,
                                color: _kTextMuted.withAlpha(200),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── Bottom Action Buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _proceedToDashboard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isDriver ? 'Izinkan & Lanjut' : 'Izinkan Semua',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: _proceedToDashboard,
                      child: Text(
                        isDriver ? 'Kenapa izin ini wajib?' : 'Atur nanti',
                        style: TextStyle(
                          color: _kTextMuted.withAlpha(220),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  final Color? badgeColor;
  final String description;
  final bool enabled;
  final Color accentColor;
  final bool highlightBorder;
  final ValueChanged<bool> onChanged;

  const _PermissionCard({
    required this.icon,
    required this.title,
    this.badge,
    this.badgeColor,
    required this.description,
    required this.enabled,
    required this.accentColor,
    this.highlightBorder = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = (highlightBorder && enabled) ? accentColor : _kBorder;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: (highlightBorder && enabled) ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon box
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 22),
          ),
          const SizedBox(width: 12),

          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor!.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kTextMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Switch
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Switch(
              value: enabled,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF2E9E57),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFE5E7EB),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
