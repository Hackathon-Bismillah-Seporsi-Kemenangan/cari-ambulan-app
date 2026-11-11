import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/pill_bottom_nav.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../emergency/domain/emergency_models.dart';
import '../../../emergency/presentation/providers/emergency_provider.dart';
import '../../../emergency/presentation/widgets/ambulance_tracking_view.dart';
import '../../../emergency/presentation/widgets/searching_ambulance_view.dart';
import 'emergency_history_page.dart';
import 'medical_id_page.dart';
import 'user_home_page.dart';
import 'user_profile_page.dart';

/// Root of the patient role: tabs Beranda / Riwayat / Medical ID / Profil.
///
/// An open request takes the whole screen over the tabs: the search, then
/// the ambulance live on the map.
class UserShell extends ConsumerStatefulWidget {
  const UserShell({super.key, required this.user});

  final AuthUser user;

  @override
  ConsumerState<UserShell> createState() => _UserShellState();
}

class _UserShellState extends ConsumerState<UserShell> {
  static const _historyTab = 1;
  static const _medicalIdTab = 2;

  int _index = 0;

  /// Tabs are built on first visit, so Riwayat doesn't load at startup.
  final _visited = {0};

  void _select(int index) {
    // Show requests finished since the list was last loaded.
    if (index == _historyTab && index != _index) {
      ref.invalidate(emergencyHistoryProvider);
    }
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tell the user how a request ended when it wasn't their own cancel.
    ref.listen<EmergencyState>(emergencyProvider, (_, next) {
      if (next case EmergencyInitial(:final closed?)) {
        final hospital = closed.hospital?.name;
        final message = closed.status != EmergencyRequestStatus.completed
            ? 'Pesanan ambulans dibatalkan.'
            : hospital == null
            ? 'Pasien telah diserahkan ke IGD. Semoga lekas sembuh!'
            : 'Pasien telah diserahkan ke IGD $hospital. '
                  'Semoga lekas sembuh!';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    });

    final emergencyState = ref.watch(emergencyProvider);
    if (emergencyState case EmergencyActive(:final request)) {
      return request.status.isSearching
          ? SearchingAmbulanceView(request: request)
          : AmbulanceTrackingView(request: request);
    }

    Widget tab(int index, Widget page) =>
        _visited.contains(index) ? page : const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          UserHomePage(user: widget.user),
          tab(_historyTab, const EmergencyHistoryPage()),
          tab(_medicalIdTab, const MedicalIdPage(inTab: true)),
          tab(
            3,
            UserProfilePage(onOpenMedicalId: () => _select(_medicalIdTab)),
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
        onTap: _select,
      ),
    );
  }
}
