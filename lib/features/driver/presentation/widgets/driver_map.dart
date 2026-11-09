import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/map/map_tiles.dart';

/// Map background for the driver screens.
///
/// One tile style is used for both states; offline only fades a grey wash
/// over it, so toggling never re-renders tiles.
class DriverMap extends StatelessWidget {
  const DriverMap({
    super.key,
    required this.controller,
    required this.location,
    required this.isOnline,
    this.route = const [],
    this.destination,
    this.onMapReady,
    this.showAttribution = true,
  });

  final MapController controller;
  final LatLng location;
  final bool isOnline;

  /// Driving route to draw, e.g. towards the patient.
  final List<LatLng> route;

  /// Pickup or hospital, shown as a blue location dot.
  final LatLng? destination;
  final VoidCallback? onMapReady;

  /// Off when the screen shows the attribution itself, e.g. above a sheet.
  final bool showAttribution;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: location,
        initialZoom: 15,
        minZoom: 5,
        maxZoom: 19,
        backgroundColor: MapTiles.background,
        onMapReady: onMapReady,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
          // Avoid accidental rotation while panning, like Google Maps.
          rotationThreshold: 25,
        ),
      ),
      children: [
        const MapTiles(),
        // A plain translucent fill: no saveLayer, unlike a ColorFilter.
        IgnorePointer(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            color: isOnline
                ? AppColors.offlineLight.withValues(alpha: 0)
                : AppColors.offlineLight.withValues(alpha: 0.6),
          ),
        ),
        if (route.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route,
                strokeWidth: 6,
                color: AppColors.primary,
                borderStrokeWidth: 2,
                borderColor: Colors.white,
              ),
            ],
          ),
        MarkerLayer(
          // Keep the markers upright when the map is rotated.
          rotate: true,
          markers: [
            if (destination != null)
              Marker(
                point: destination!,
                width: 56,
                height: 56,
                child: const _DestinationDot(),
              ),
            Marker(
              point: location,
              width: 130,
              height: 130,
              child: _AmbulanceMarker(isOnline: isOnline),
            ),
          ],
        ),
        if (showAttribution)
          const SimpleAttributionWidget(
            source: Text(MapTiles.attribution, style: TextStyle(fontSize: 10)),
          ),
      ],
    );
  }
}

/// Ambulance puck with a Google Maps-style pulsing halo while online.
class _AmbulanceMarker extends StatefulWidget {
  const _AmbulanceMarker({required this.isOnline});

  final bool isOnline;

  @override
  State<_AmbulanceMarker> createState() => _AmbulanceMarkerState();
}

class _AmbulanceMarkerState extends State<_AmbulanceMarker>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(_AmbulanceMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOnline != widget.isOnline) _syncPulse();
  }

  void _syncPulse() {
    if (widget.isOnline) {
      _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.isOnline;
    final haloColor = isOnline ? AppColors.primary : AppColors.offline;

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: haloColor.withValues(alpha: 0.12),
            border: Border.all(color: haloColor.withValues(alpha: 0.35)),
          ),
        ),
        if (isOnline)
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = Curves.easeOut.transform(_pulse.value);
                return Container(
                  width: 52 + 68 * t,
                  height: 52 + 68 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: haloColor.withValues(alpha: 0.25 * (1 - t)),
                  ),
                );
              },
            ),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isOnline ? AppColors.ambulance : AppColors.offline,
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
            size: 24,
          ),
        ),
      ],
    );
  }
}

/// Destination, styled like Google Maps' blue location dot.
class _DestinationDot extends StatelessWidget {
  const _DestinationDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 56,
        height: 56,
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
