import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

enum TimelineStatus { done, active, pending }

class TimelineEntry {
  const TimelineEntry({
    required this.label,
    required this.status,
    this.caption,
  });

  final String label;
  final TimelineStatus status;

  /// Time it happened, or an ETA for the active step.
  final String? caption;
}

/// Vertical order-progress list: green checks for finished steps, a red
/// marker for the current one, empty circles for what's left.
class TripTimeline extends StatelessWidget {
  const TripTimeline({super.key, required this.entries});

  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            _Row(
              entry: entries[i],
              isLast: i == entries.length - 1,
              // The connector below a step is green once the next one started.
              lineDone:
                  i < entries.length - 1 &&
                  entries[i + 1].status != TimelineStatus.pending,
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.entry,
    required this.isLast,
    required this.lineDone,
  });

  final TimelineEntry entry;
  final bool isLast;
  final bool lineDone;

  @override
  Widget build(BuildContext context) {
    final isPending = entry.status == TimelineStatus.pending;
    final isActive = entry.status == TimelineStatus.active;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                _Dot(status: entry.status),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: lineDone ? AppColors.online : AppColors.divider,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3, bottom: isLast ? 8 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isPending
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (entry.caption != null)
                    Text(
                      entry.caption!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive
                            ? AppColors.emergency
                            : AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.status});

  final TimelineStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      TimelineStatus.done => Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppColors.online,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
      ),
      TimelineStatus.active => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.emergency,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.emergencyLight, width: 3),
        ),
        child: const Icon(
          Icons.navigation_rounded,
          color: Colors.white,
          size: 14,
        ),
      ),
      TimelineStatus.pending => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider, width: 2),
        ),
      ),
    };
  }
}
