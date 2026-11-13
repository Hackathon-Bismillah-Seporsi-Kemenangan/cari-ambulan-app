import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/alerts/emergency_alert.dart';
import '../../../../core/widgets/pill_bottom_nav.dart';

import 'driver_history_page.dart';
import 'driver_home_page.dart';
import 'driver_profile_page.dart';

/// Root of the driver role: tabs Beranda / Riwayat / Profil.
class DriverShell extends ConsumerStatefulWidget {
  const DriverShell({super.key});

  @override
  ConsumerState<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends ConsumerState<DriverShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Asks for the notification permission used by emergency calls.
    EmergencyAlert.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [
          DriverHomePage(),
          DriverHistoryPage(),
          DriverProfilePage(),
        ],
      ),
      bottomNavigationBar: PillBottomNav(
        items: const [
          (icon: Icons.home_outlined, label: 'Beranda'),
          (icon: Icons.history_rounded, label: 'Riwayat'),
          (icon: Icons.person_outline_rounded, label: 'Profil'),
        ],
        currentIndex: _index,
        onTap: (i) {
          // Show trips finished since the list was last loaded.
          if (i == 1 && i != _index) ref.invalidate(driverTripHistoryProvider);
          setState(() => _index = i);
        },
      ),
    );
  }
}
