import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/user_role.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand_mark.dart';

const _border = Color(0xFFE5E7EB);

/// First screen after installing: "Pilih peran Anda" (design "Shared").
/// The saved role picks the onboarding and the login that follow.
class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({
    super.key,
    required this.onSelected,
    this.initialRole = UserRole.patient,
    this.isBusy = false,
  });

  final UserRole initialRole;
  final ValueChanged<UserRole> onSelected;
  final bool isBusy;

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage>
    with SingleTickerProviderStateMixin {
  late UserRole _selected = widget.initialRole;
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _entrance.value = 1;
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// Fades and lifts [child] in during [begin]–[end] of the entrance.
  Widget _stagger(double begin, double end, Widget child) {
    final animation = CurvedAnimation(
      parent: _entrance,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: child,
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
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _stagger(0, 0.5, const _Brand()),
                        const SizedBox(height: 32),
                        _stagger(
                          0.1,
                          0.6,
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.roleSelectionTitle,
                                style: TextStyle(
                                  fontSize: 28,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                AppStrings.roleSelectionSubtitle,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.45,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        _stagger(
                          0.2,
                          0.75,
                          _RoleCard(
                            role: UserRole.patient,
                            selected: _selected.isPatient,
                            onTap: () =>
                                setState(() => _selected = UserRole.patient),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _stagger(
                          0.3,
                          0.85,
                          _RoleCard(
                            role: UserRole.driver,
                            selected: _selected.isDriver,
                            onTap: () =>
                                setState(() => _selected = UserRole.driver),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                    child: _stagger(
                      0.4,
                      1,
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton(
                            onPressed: widget.isBusy
                                ? null
                                : () => widget.onSelected(_selected),
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
                            child: Text(
                              _selected.isPatient
                                  ? AppStrings.continueAsPatient
                                  : AppStrings.continueAsDriver,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            AppStrings.roleSelectionNote,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
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

/// The logo and "CariAmbulan".
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BrandMark(size: 40),
        const SizedBox(width: 12),
        const Flexible(
          child: Text(
            AppStrings.appName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPatient = role.isPatient;
    final accent = isPatient ? AppColors.emergency : AppColors.primary;
    final tint = isPatient ? AppColors.emergencyLight : AppColors.primaryLight;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? tint : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? accent : _border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        // White on the tinted selected card.
                        color: selected ? Colors.white : tint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPatient
                            ? Icons.monitor_heart_outlined
                            : Icons.airport_shuttle_outlined,
                        color: accent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        isPatient
                            ? AppStrings.rolePatient
                            : AppStrings.roleDriver,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Check(selected: selected, color: accent),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  isPatient
                      ? AppStrings.rolePatientDesc
                      : AppStrings.roleDriverDesc,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSecondary,
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

/// A filled check when selected, an empty ring otherwise.
class _Check extends StatelessWidget {
  const _Check({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: selected
            ? null
            : Border.all(color: AppColors.textSecondary, width: 1.8),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
          : null,
    );
  }
}
