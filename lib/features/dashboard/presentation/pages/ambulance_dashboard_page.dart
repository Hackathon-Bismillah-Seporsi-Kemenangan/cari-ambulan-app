import 'dart:async';
import 'package:flutter/material.dart';
import '../../../onboarding/data/onboarding_repository.dart';
import '../../../../main.dart';

const _kBlue = Color(0xFF1565C0);
const _kRed = Color(0xFFE53935);
const _kGreen = Color(0xFF2E9E57);
const _kDark = Color(0xFF0F172A);
const _kMuted = Color(0xFF64748B);
const _kBorder = Color(0xFFE2E8F0);
const _kSurface = Color(0xFFF8FAFC);

/// Dashboard khusus Driver Ambulans & Paramedis
class AmbulanceDashboardPage extends StatefulWidget {
  final OnboardingRepository? repository;
  final VoidCallback? onSwitchRole;

  const AmbulanceDashboardPage({super.key, this.repository, this.onSwitchRole});

  @override
  State<AmbulanceDashboardPage> createState() => _AmbulanceDashboardPageState();
}

class _AmbulanceDashboardPageState extends State<AmbulanceDashboardPage>
    with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  bool _orderAccepted = false;
  int _activeNav = 0;
  int _countdown = 15;
  Timer? _countdownTimer;

  late final AnimationController _radarCtrl;

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = 15;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown > 0 && _isOnline && !_orderAccepted) {
        setState(() => _countdown--);
      } else if (_countdown == 0) {
        // Reset or simulated next order
        setState(() {
          _countdown = 15;
        });
      }
    });
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
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
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _kBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'SigapMed',
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
                  color: const Color(0xFFE3F0FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Driver',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kBlue,
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
              tooltip: 'Ganti ke Pasien Mode',
              icon: const Icon(
                Icons.swap_horiz_rounded,
                size: 22,
                color: _kRed,
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
                        Icon(Icons.swap_horiz, size: 18, color: _kRed),
                        SizedBox(width: 8),
                        Text('Beralih ke Pasien / Keluarga'),
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
            // ── Driver Info & Unit Badge
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kDark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kBlue.withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBlue.withAlpha(90)),
                    ),
                    child: const Icon(
                      Icons.emergency_share_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Budi Santoso • Unit Ambulans #B-102',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ambulans Tipe B (Gawat Darurat) • RS Siloam Partner',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF065F46),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Terverifikasi ✓',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6EE7B7),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Status Switch Card (ONLINE / OFFLINE)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isOnline
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _isOnline ? const Color(0xFF86EFAC) : _kBorder,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    // Radar icon if online
                    if (_isOnline)
                      AnimatedBuilder(
                        animation: _radarCtrl,
                        builder: (context, child) {
                          return Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kGreen.withAlpha(25),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.radar_rounded,
                                color: _kGreen,
                                size: 24,
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kMuted.withAlpha(20),
                        ),
                        child: const Icon(
                          Icons.power_settings_new_rounded,
                          color: _kMuted,
                          size: 24,
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isOnline
                                ? 'SIAP TERIMA ORDER DARURAT'
                                : 'STATUS OFFLINE (ISTIRAHAT)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _isOnline
                                  ? const Color(0xFF166534)
                                  : _kMuted,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isOnline
                                ? 'GPS Siaga • Radius 5.0 KM • Siap dalam 15s'
                                : 'Nyalakan switch untuk terima order sekitar',
                            style: TextStyle(
                              fontSize: 11,
                              color: _isOnline
                                  ? const Color(0xFF15803D)
                                  : _kMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isOnline,
                      onChanged: (v) => setState(() {
                        _isOnline = v;
                        if (!v) _orderAccepted = false;
                      }),
                      activeThumbColor: Colors.white,
                      activeTrackColor: _kGreen,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: _kBorder,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Live Dispatch Emergency Card (Simulated Incoming Alert)
            if (_isOnline) ...[
              if (!_orderAccepted)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kRed, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _kRed.withAlpha(35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _kRed,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.warning_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'PANGGILAN DARURAT MASUK!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDECEC),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Respon: ${_countdown}s',
                                style: const TextStyle(
                                  color: _kRed,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'KODE MERAH • Trauma Kecelakaan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _kDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: _kBlue,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Jl. Rasuna Said No. 12 (1.4 km • 4 menit)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _kDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          children: [
                            Icon(
                              Icons.local_hospital_rounded,
                              color: _kGreen,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Rujukan Siaga: IGD RS Siloam Semanggi (6 Bed Siaga)',
                                style: TextStyle(fontSize: 12, color: _kMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() => _orderAccepted = true);
                                },
                                icon: const Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'TERIMA TUGAS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: _kBorder),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() => _countdown = 15);
                                },
                                child: const Text(
                                  'OPER UNIT',
                                  style: TextStyle(
                                    color: _kMuted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Active Mission in Progress Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _kGreen,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'TUGAS SEDANG BERJALAN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                              ),
                              onPressed: () {
                                setState(() => _orderAccepted = false);
                              },
                              child: const Text(
                                'Batal',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Menuju Lokasi Pasien',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Jl. Rasuna Said No. 12 • ETA: 3 Menit',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const AuthGate(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.navigation_rounded,
                                  size: 18,
                                ),
                                label: const Text('Buka GPS Navigasi'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF334155),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.phone_rounded),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              setState(() => _orderAccepted = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Pasien telah diserahterimakan ke IGD RS! Tugas selesai.',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Selesai di IGD RS'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 24),

            // ── Shift Stats (Performa Driver Hari Ini)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Performa Shift Hari Ini',
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
              child: Row(
                children: const [
                  _DriverStatCard(
                    icon: Icons.emergency_share_rounded,
                    label: 'Tugas Selesai',
                    value: '5 Pasien',
                    color: _kBlue,
                  ),
                  SizedBox(width: 10),
                  _DriverStatCard(
                    icon: Icons.timer_outlined,
                    label: 'Waktu Respon',
                    value: '3.8 Menit',
                    color: _kGreen,
                  ),
                  SizedBox(width: 10),
                  _DriverStatCard(
                    icon: Icons.star_rounded,
                    label: 'Rating Driver',
                    value: '⭐ 4.98',
                    color: Color(0xFFF59E0B),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Tactical Tools (Alat Operasional Driver)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Fitur Operasional Driver',
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
                  _ToolCard(
                    icon: Icons.map_rounded,
                    title: 'Peta & GPS Driver',
                    desc: 'Mode siaga & rute pasien',
                    accentColor: _kBlue,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AuthGate()),
                      );
                    },
                  ),
                  _ToolCard(
                    icon: Icons.local_hospital_rounded,
                    title: 'Status Kapasitas IGD',
                    desc: 'Cek bed kosong di 14 RS',
                    accentColor: _kGreen,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AuthGate()),
                      );
                    },
                  ),
                  _ToolCard(
                    icon: Icons.medical_services_rounded,
                    title: 'Checklist Alkes',
                    desc: 'Tabung O2 (98%) • AED OK',
                    accentColor: const Color(0xFF7C3AED),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AuthGate()),
                      );
                    },
                  ),
                  _ToolCard(
                    icon: Icons.headset_mic_rounded,
                    title: 'Radio Komando 119',
                    desc: 'Kanal SPGDT Langsung',
                    accentColor: _kRed,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AuthGate()),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Log Tugas Hari Ini
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Riwayat Respon Terakhir',
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
                _HistoryItem(
                  code: '#08-042',
                  caseName: 'Serangan Jantung Akut',
                  destination: 'Selesai di IGD RS Jantung Harapan Kita',
                  time: '14:20 • 18 menit',
                ),
                SizedBox(height: 10),
                _HistoryItem(
                  code: '#08-041',
                  caseName: 'Asma Berat & Syok',
                  destination: 'Selesai di IGD RSUD Pasar Minggu',
                  time: '11:05 • 12 menit',
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
        selectedItemColor: _kBlue,
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
            icon: Icon(Icons.radar_rounded),
            label: 'Radar Order',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.navigation_outlined),
            activeIcon: Icon(Icons.navigation_rounded),
            label: 'Rute GPS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2_rounded),
            label: 'Armada & Alkes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.account_circle_rounded),
            label: 'Akun Mitra',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets for Driver Dashboard
// ─────────────────────────────────────────────────────────────────────────────

class _DriverStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DriverStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: _kMuted)),
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color accentColor;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.accentColor,
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
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
                    desc,
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

class _HistoryItem extends StatelessWidget {
  final String code;
  final String caseName;
  final String destination;
  final String time;

  const _HistoryItem({
    required this.code,
    required this.caseName,
    required this.destination,
    required this.time,
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4EA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: _kGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      caseName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kDark,
                      ),
                    ),
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  destination,
                  style: const TextStyle(fontSize: 11, color: _kMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(fontSize: 10, color: _kMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
