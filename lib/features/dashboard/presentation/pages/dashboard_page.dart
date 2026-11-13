import 'package:flutter/material.dart';
import '../../../../core/constants/user_role.dart';
import '../../../onboarding/data/onboarding_repository.dart';
import 'user_dashboard_page.dart';
import 'ambulance_dashboard_page.dart';

/// Halaman Dashboard Utama.
/// Mengarahkan secara dinamis ke [UserDashboardPage] untuk Pasien / Keluarga
/// atau [AmbulanceDashboardPage] untuk Driver Ambulans.
class DashboardPage extends StatefulWidget {
  final UserRole role;
  final OnboardingRepository? repository;

  const DashboardPage({super.key, required this.role, this.repository});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late UserRole _currentRole;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.role;
  }

  void _switchRole() async {
    final nextRole = _currentRole.isPatient
        ? UserRole.driver
        : UserRole.patient;
    setState(() => _currentRole = nextRole);
    if (widget.repository != null) {
      await widget.repository!.completeOnboarding(nextRole);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentRole.isDriver) {
      return AmbulanceDashboardPage(
        repository: widget.repository,
        onSwitchRole: _switchRole,
      );
    } else {
      return UserDashboardPage(
        repository: widget.repository,
        onSwitchRole: _switchRole,
      );
    }
  }
}
