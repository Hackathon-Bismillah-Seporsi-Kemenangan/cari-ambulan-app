import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pill_bottom_nav.dart';
import 'emergency_history_page.dart';
import 'medical_id_page.dart';
import 'user_home_page.dart';
import 'user_profile_page.dart';

/// Root of the user (patient / caller) role: Beranda / Riwayat / Medical ID
/// / Profil.
class UserShell extends StatefulWidget {
  const UserShell({super.key});

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  static const _medicalIdTab = 2;
  static const _profileTab = 3;

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // White pages, so the grey cards on Medical ID and Profil stand out.
      backgroundColor: AppColors.surface,
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          UserHomePage(
            onOpenProfile: () => setState(() => _index = _profileTab),
          ),
          const EmergencyHistoryPage(),
          const MedicalIdPage(),
          UserProfilePage(
            onOpenMedicalId: () => setState(() => _index = _medicalIdTab),
          ),
        ],
      ),
      bottomNavigationBar: PillBottomNav(
        items: const [
          (icon: Icons.home_outlined, label: 'Beranda'),
          (icon: Icons.history_rounded, label: 'Riwayat'),
          (icon: Icons.badge_outlined, label: 'Medical ID'),
          (icon: Icons.person_outline_rounded, label: 'Profil'),
        ],
        currentIndex: _index,
        color: AppColors.emergency,
        selectedBackground: AppColors.emergencyLight,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
