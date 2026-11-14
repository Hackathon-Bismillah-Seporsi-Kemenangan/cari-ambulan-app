import 'package:flutter/material.dart';
import '../../../onboarding/data/onboarding_repository.dart';
import '../../../../main.dart';
import '../../../../core/widgets/brand_mark.dart';

const _kBlue = Color(0xFF1565C0);
const _kRed = Color(0xFFE53935);
const _kDark = Color(0xFF1B2A4A);
const _kMuted = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kSurface = Color(0xFFF8FAFC);

/// Dashboard khusus Pasien / Keluarga
class UserDashboardPage extends StatefulWidget {
  final OnboardingRepository? repository;
  final VoidCallback? onSwitchRole;

  const UserDashboardPage({super.key, this.repository, this.onSwitchRole});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  int _activeNav = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _triggerSos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SosTrackingSheet(onDismiss: () {}),
    );
  }

  void _resetApp() async {
    if (widget.repository != null) {
      await widget.repository!.resetOnboarding();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 28),
              const SizedBox(width: 8),
              const Text(
                'CariAmbulan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _kDark,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Pasien',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kRed,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Switch role pill for dev testing
          if (widget.onSwitchRole != null)
            IconButton(
              tooltip: 'Ganti ke Driver Mode',
              icon: const Icon(
                Icons.swap_horiz_rounded,
                size: 22,
                color: _kBlue,
              ),
              onPressed: widget.onSwitchRole,
            ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: _kDark),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              icon: const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFFE2E8F0),
                child: Icon(Icons.person, size: 18, color: _kDark),
              ),
              onSelected: (val) {
                if (val == 'reset') _resetApp();
                if (val == 'switch') widget.onSwitchRole?.call();
              },
              itemBuilder: (_) => [
                if (widget.onSwitchRole != null)
                  const PopupMenuItem(
                    value: 'switch',
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz, size: 18, color: _kBlue),
                        SizedBox(width: 8),
                        Text('Beralih ke Driver Ambulans'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.restart_alt, size: 18, color: _kRed),
                      SizedBox(width: 8),
                      Text('Ulang Onboarding (Reset)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Lokasi Terkini Bar
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: _kRed, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lokasi Jemput Anda',
                          style: TextStyle(
                            fontSize: 10,
                            color: _kMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Jl. Gatot Subroto No. 45, Jakarta Selatan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorder),
                    ),
                    child: const Text(
                      'Ubah',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── HERO: Tombol Utama SOS Panggilan Darurat
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE53935), Color(0xFFC62828)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _kRed.withAlpha(80),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'BUTUH BANTUAN MEDIS DARURAT?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tekan tombol di bawah untuk kirim ambulans terdekat',
                        style: TextStyle(
                          color: Colors.white.withAlpha(220),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Pulsing SOS Circle Button
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (context, child) {
                          final scale = 1.0 + (_pulseCtrl.value * 0.08);
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: GestureDetector(
                          onTap: _triggerSos,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(40),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.emergency_rounded,
                                  color: _kRed,
                                  size: 44,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'SOS',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: _kRed,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '18 Ambulans Aktif • Estimasi 3-5 Menit',
                              style: TextStyle(
                                color: Colors.white.withAlpha(230),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Quick Emergency Hotlines
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _HotlinePill(
                    icon: Icons.phone_in_talk_rounded,
                    label: 'Call 119 (SPGDT)',
                    color: _kRed,
                    onTap: () {},
                  ),
                  const SizedBox(width: 10),
                  _HotlinePill(
                    icon: Icons.local_hospital_rounded,
                    label: 'Ambulans PMI',
                    color: _kBlue,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Medical ID Card (Preview)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.badge_rounded, color: _kBlue, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Medical ID Pasien',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _kDark,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F0FC),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'BPJS Aktif',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _kBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Expanded(
                          child: _IdField(
                            label: 'Gol. Darah',
                            value: 'O Positif (O+)',
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _IdField(label: 'Alergi', value: 'Penisilin'),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _IdField(
                            label: 'Kontak Darurat',
                            value: 'Istri (0812-xx)',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _kBlue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {},
                        child: const Text(
                          'Lihat & Lengkapi Data Medis',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kBlue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Layanan Utama
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Layanan CariAmbulan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _kDark,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _ServiceCard(
                    icon: Icons.emergency_rounded,
                    title: 'Gawat Darurat',
                    subtitle: 'Unit ICU & Paramedis Siaga',
                    accentColor: _kRed,
                    badge: '24 Jam',
                    onTap: _triggerSos,
                  ),
                  _ServiceCard(
                    icon: Icons.airport_shuttle_rounded,
                    title: 'Transport Medis',
                    subtitle: 'Rujukan & Kontrol Pasien',
                    accentColor: _kBlue,
                    onTap: () {},
                  ),
                  _ServiceCard(
                    icon: Icons.local_hospital_rounded,
                    title: 'IGD RS Terdekat',
                    subtitle: 'Cek Bed & Fasilitas Siaga',
                    accentColor: const Color(0xFF2E9E57),
                    onTap: () {},
                  ),
                  _ServiceCard(
                    icon: Icons.support_agent_rounded,
                    title: 'Konsultasi Paramedis',
                    subtitle: 'Panduan medis darurat',
                    accentColor: const Color(0xFF7C3AED),
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── RS Rujukan Terdekat
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Rumah Sakit Siaga Terdekat',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _kDark,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: const [
                _HospitalItem(
                  name: 'RSUD Pasar Minggu',
                  distance: '1.2 km • 5 menit',
                  bedStatus: '8 Bed IGD Tersedia',
                  ambulanceCount: '3 Ambulans Siaga',
                  isOpen: true,
                ),
                SizedBox(height: 10),
                _HospitalItem(
                  name: 'RS Siloam TB Simatupang',
                  distance: '2.5 km • 9 menit',
                  bedStatus: '4 Bed IGD Tersedia',
                  ambulanceCount: '2 Ambulans Siaga',
                  isOpen: true,
                ),
                SizedBox(height: 10),
                _HospitalItem(
                  name: 'RS Fatmawati (Pusat Trauma)',
                  distance: '3.8 km • 14 menit',
                  bedStatus: '12 Bed IGD Tersedia',
                  ambulanceCount: '5 Ambulans Siaga',
                  isOpen: true,
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _activeNav,
        onTap: (i) => setState(() => _activeNav = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _kRed,
        unselectedItemColor: _kMuted,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.emergency_outlined),
            activeIcon: Icon(Icons.emergency_rounded),
            label: 'Panggilan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.badge_outlined),
            activeIcon: Icon(Icons.badge_rounded),
            label: 'Medical ID',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _HotlinePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HotlinePill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
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

class _IdField extends StatelessWidget {
  final String label;
  final String value;
  const _IdField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: _kMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _kDark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final String? badge;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _kBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: _kMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _HospitalItem extends StatelessWidget {
  final String name;
  final String distance;
  final String bedStatus;
  final String ambulanceCount;
  final bool isOpen;

  const _HospitalItem({
    required this.name,
    required this.distance,
    required this.bedStatus,
    required this.ambulanceCount,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_hospital_rounded,
              color: _kBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  distance,
                  style: const TextStyle(fontSize: 11, color: _kMuted),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4EA),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        bedStatus,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E9E57),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ambulanceCount,
                      style: const TextStyle(
                        fontSize: 10,
                        color: _kBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _kMuted),
        ],
      ),
    );
  }
}

/// Simulated Live Tracking Sheet when SOS is pressed
class _SosTrackingSheet extends StatelessWidget {
  final VoidCallback onDismiss;
  const _SosTrackingSheet({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFDECEC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emergency_share_rounded,
                  color: _kRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ambulans Menuju Lokasi Anda!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _kDark,
                      ),
                    ),
                    Text(
                      'Estimasi kedatangan: 3-5 Menit',
                      style: TextStyle(
                        fontSize: 12,
                        color: _kRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: _kBlue,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driver: Ahmad Kurniawan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kDark,
                        ),
                      ),
                      Text(
                        'Unit #B-102 • RSUD Pasar Minggu',
                        style: TextStyle(fontSize: 11, color: _kMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.phone_rounded,
                    color: Color(0xFF2E9E57),
                  ),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                onDismiss();
              },
              child: const Text(
                'Tutup Pelacakan',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
