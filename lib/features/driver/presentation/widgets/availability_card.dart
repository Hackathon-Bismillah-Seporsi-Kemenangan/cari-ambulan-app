import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/driver_models.dart';

/// Top card with the ONLINE/OFFLINE label and the power switch.
class AvailabilityCard extends StatelessWidget {
  const AvailabilityCard({
    super.key,
    required this.profile,
    required this.isOnline,
    required this.isBusy,
    required this.onToggle,
  });

  final DriverProfile profile;
  final bool isOnline;
  final bool isBusy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.online : AppColors.offline;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOnline ? AppColors.online : Colors.transparent,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOnline ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isOnline
                      ? '${profile.vehiclePlate} · ${profile.vehicleType}'
                      : 'Aktifkan saat siap bertugas',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isOnline
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PowerSwitch(value: isOnline, isBusy: isBusy, onTap: onToggle),
        ],
      ),
    );
  }
}

/// Pill switch whose thumb carries a power icon, matching the design.
class PowerSwitch extends StatelessWidget {
  const PowerSwitch({
    super.key,
    required this.value,
    required this.isBusy,
    required this.onTap,
  });

  final bool value;
  final bool isBusy;
  final VoidCallback onTap;

  static const _width = 84.0;
  static const _height = 48.0;
  static const _thumb = 40.0;

  @override
  Widget build(BuildContext context) {
    final trackColor = value ? AppColors.online : AppColors.offlineLight;

    return Semantics(
      toggled: value,
      button: true,
      label: value
          ? 'Online, ketuk untuk offline'
          : 'Offline, ketuk untuk online',
      child: GestureDetector(
        onTap: isBusy ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: _width,
          height: _height,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(_height / 2),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: _thumb,
              height: _thumb,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: isBusy
                  ? Padding(
                      padding: const EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: value ? AppColors.online : AppColors.offline,
                      ),
                    )
                  : Icon(
                      Icons.power_settings_new_rounded,
                      size: 20,
                      color: value ? AppColors.online : AppColors.offline,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
