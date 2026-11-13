import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/route_models.dart';

/// "300 m" / "1.8 km", rounded like a navigation app.
String formatDistance(double meters) {
  if (meters < 1000) {
    final rounded = meters < 100
        ? (meters / 10).round() * 10
        : (meters / 50).round() * 50;
    return '${rounded.clamp(10, 1000)} m';
  }
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Blue turn-by-turn card at the top of the navigation screen.
class ManeuverBanner extends StatelessWidget {
  const ManeuverBanner({super.key, required this.route, this.arrived = false});

  /// Null while the route is loading.
  final DriveRoute? route;
  final bool arrived;

  static IconData iconFor(Maneuver maneuver) => switch (maneuver) {
    Maneuver.depart || Maneuver.straight => Icons.straight_rounded,
    Maneuver.slightLeft => Icons.turn_slight_left_rounded,
    Maneuver.left => Icons.turn_left_rounded,
    Maneuver.sharpLeft => Icons.turn_sharp_left_rounded,
    Maneuver.slightRight => Icons.turn_slight_right_rounded,
    Maneuver.right => Icons.turn_right_rounded,
    Maneuver.sharpRight => Icons.turn_sharp_right_rounded,
    Maneuver.uTurn => Icons.u_turn_left_rounded,
    Maneuver.roundabout => Icons.roundabout_right_rounded,
    Maneuver.arrive => Icons.flag_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final route = this.route;
    final next = route?.nextManeuver;

    final (Widget icon, String title, String subtitle) = switch (route) {
      _ when arrived => (
        const Icon(Icons.flag_rounded, color: Colors.white, size: 34),
        'Anda sudah tiba',
        'Temui pasien di lokasi jemput',
      ),
      null => (
        const SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
        ),
        'Menghitung rute…',
        'Mohon tunggu sebentar',
      ),
      DriveRoute(isEstimate: true) => (
        const Icon(Icons.near_me_rounded, color: Colors.white, size: 34),
        formatDistance(route.distanceMeters),
        'Rute tidak tersedia, ikuti arah ke pasien',
      ),
      _ => (
        Icon(
          iconFor(next?.maneuver ?? Maneuver.arrive),
          color: Colors.white,
          size: 36,
        ),
        formatDistance(route.distanceToNextManeuver),
        next?.instruction ?? 'Tiba di lokasi pasien',
      ),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: arrived ? AppColors.online : AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(width: 40, child: Center(child: icon)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
