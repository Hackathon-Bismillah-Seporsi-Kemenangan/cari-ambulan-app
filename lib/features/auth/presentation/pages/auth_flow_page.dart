import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/user_role.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../onboarding/data/onboarding_repository.dart';
import '../../../onboarding/presentation/pages/driver_onboarding_page.dart';
import '../../../onboarding/presentation/pages/access_permission_page.dart';
import '../../../onboarding/presentation/pages/patient_onboarding_page.dart';
import '../../../onboarding/presentation/pages/role_selection_page.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import 'login_page.dart';
import 'register_page.dart';

/// Only mounted after AuthGate has confirmed there is no signed-in session.
class AuthFlowPage extends ConsumerWidget {
  const AuthFlowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(onboardingRepositoryProvider)
        .when(
          data: (repository) => _GuestJourney(repository: repository),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded, size: 40),
                      const SizedBox(height: 16),
                      const Text(
                        'Pengaturan aplikasi belum dapat dibaca.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () =>
                            ref.invalidate(onboardingRepositoryProvider),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
  }
}

enum _GuestStep { role, introduction, permissions, login, register }

class _GuestJourney extends StatefulWidget {
  const _GuestJourney({required this.repository});

  final OnboardingRepository repository;

  @override
  State<_GuestJourney> createState() => _GuestJourneyState();
}

class _GuestJourneyState extends State<_GuestJourney> {
  late UserRole _role;
  late _GuestStep _step;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final savedRole = widget.repository.savedRole;
    _role = savedRole ?? UserRole.patient;
    _step = widget.repository.isOnboardingComplete
        ? _GuestStep.login
        : savedRole == null
        ? _GuestStep.role
        : _GuestStep.introduction;
  }

  void _show(_GuestStep step) {
    if (!_busy) setState(() => _step = step);
  }

  void _setBusy(bool value) {
    if (mounted) setState(() => _busy = value);
  }

  Future<void> _selectRole(UserRole role) async {
    if (_busy) return;
    _setBusy(true);
    try {
      await widget.repository.selectRole(role);
      if (!mounted) return;
      setState(() {
        _role = role;
        _step = _GuestStep.introduction;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilihan peran belum tersimpan. Coba lagi.'),
          ),
        );
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _completeOnboarding() async {
    if (_busy) return;
    _setBusy(true);
    try {
      await widget.repository.completeOnboarding(_role);
      if (mounted) {
        setState(() => _step = _GuestStep.permissions);
      }
    } finally {
      _setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_step) {
      _GuestStep.role => RoleSelectionPage(
        initialRole: _role,
        isBusy: _busy,
        onSelected: _selectRole,
      ),
      _GuestStep.introduction when _role.isPatient => PatientOnboardingPage(
        onCompleted: _completeOnboarding,
        onBack: () => _show(_GuestStep.role),
      ),
      _GuestStep.introduction => DriverOnboardingPage(
        onCompleted: _completeOnboarding,
        onBack: () => _show(_GuestStep.role),
      ),
      _GuestStep.permissions => AccessPermissionPage(
        role: _role,
        onDone: () => _show(_GuestStep.login),
      ),
      _GuestStep.login => LoginPage(
        role: _role,
        onRegister: () => _show(_GuestStep.register),
        onChangeRole: () => _show(_GuestStep.role),
        onBusyChanged: _setBusy,
      ),
      _GuestStep.register => RegisterPage(
        role: _role,
        onLogin: () => _show(_GuestStep.login),
        onChangeRole: () => _show(_GuestStep.role),
        onBusyChanged: _setBusy,
      ),
    };

    // The driver introduction and registration handle back themselves
    // (previous slide, previous step).
    final handlesBack =
        _step == _GuestStep.register ||
        (_step == _GuestStep.introduction && _role.isDriver);
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_busy && _step == _GuestStep.role,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _busy || handlesBack) return;
        _show(switch (_step) {
          _GuestStep.permissions => _GuestStep.introduction,
          _ => _GuestStep.role,
        });
      },
      child: Theme(
        // Blue throughout, as in the design; only the patient card is red.
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(primary: AppColors.primary),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ),
        child: page,
      ),
    );
  }
}
