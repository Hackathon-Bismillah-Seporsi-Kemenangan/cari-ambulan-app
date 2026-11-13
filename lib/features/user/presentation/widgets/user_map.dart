import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/map/map_tiles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/user_models.dart';

/// Map on the user's home screen: their position with its GPS accuracy, and
/// the nearest available ambulance with its drive time.
class UserMap extends StatelessWidget {
  const UserMap({
    super.key,
    required this.controller,
    required this.location,
    this.accuracyMeters,
    this.ambulance,
    this.onMapReady,
  });

  final MapController controller;
  final LatLng location;
  final double? accuracyMeters;
  final NearestAmbulance? ambulance;
  final VoidCallback? onMapReady;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: MapTiles.clamp(location),
        initialZoom: 15.5,
        minZoom: MapTiles.minZoom,
        cameraConstraint: MapTiles.cameraConstraint,
        maxZoom: 19,
        backgroundColor: MapTiles.background,
        onMapReady: onMapReady,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        const MapTiles(),
        if (accuracyMeters != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: location,
                // Small radii hide under the dot, so show at least 60 m.
                radius: math.max(accuracyMeters!, 60),
                useRadiusInMeter: true,
                color: AppColors.primary.withValues(alpha: 0.10),
                borderColor: AppColors.primary.withValues(alpha: 0.30),
                borderStrokeWidth: 1,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: location,
              width: 56,
              height: 56,
              child: const _UserDot(),
            ),
            if (ambulance != null)
              Marker(
                point: ambulance!.location,
                width: 120,
                height: 92,
                // Anchor the ambulance icon, not the chip below it, on the spot.
                alignment: const Alignment(0, 0.35),
                child: _AmbulanceMarker(etaMinutes: ambulance!.etaMinutes),
              ),
          ],
        ),
        MapCoverageNote(location: location),
      ],
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmbulanceMarker extends StatelessWidget {
  const _AmbulanceMarker({required this.etaMinutes});

  final int etaMinutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.emergency,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.airport_shuttle_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, size: 13, color: Colors.white),
              const SizedBox(width: 3),
              Text(
                '$etaMinutes mnt',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
