import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/map/route_trim.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/driver_models.dart';
import '../../domain/route_models.dart';
import 'driver_map.dart';

/// Shared layout for the trip screens: full-screen map with a card on top,
/// a bottom sheet, and the route fitted into the space between them.
class TripMapLayout extends StatefulWidget {
  const TripMapLayout({
    super.key,
    required this.location,
    required this.target,
    required this.route,
    required this.top,
    required this.sheet,
    this.showTargetDot = false,
    this.hospital,
  });

  final LatLng location;

  /// Where the driver is heading.
  final LatLng target;

  /// Null while loading.
  final DriveRoute? route;
  final Widget top;
  final Widget sheet;

  /// Draws [target] as a blue location dot (the patient).
  final bool showTargetDot;

  /// Shown as a labelled chip (the destination hospital).
  final NearbyHospital? hospital;

  @override
  State<TripMapLayout> createState() => _TripMapLayoutState();
}

class _TripMapLayoutState extends State<TripMapLayout> {
  final _mapController = MapController();
  final _topKey = GlobalKey();
  final _sheetKey = GlobalKey();

  @override
  void didUpdateWidget(TripMapLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route != widget.route || oldWidget.target != widget.target) {
      _fitAfterLayout();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitAfterLayout() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute());

  /// Fits the driver, target and route into the map area left visible
  /// between the top card and the bottom sheet.
  void _fitRoute() {
    if (!mounted) return;
    final top = _topKey.currentContext?.findRenderObject() as RenderBox?;
    final sheet = _sheetKey.currentContext?.findRenderObject() as RenderBox?;
    if (top == null || sheet == null || !top.hasSize || !sheet.hasSize) return;
    final topEdge = top.localToGlobal(Offset(0, top.size.height)).dy;
    final bottomInset =
        MediaQuery.sizeOf(context).height - sheet.localToGlobal(Offset.zero).dy;

    _mapController.rotate(0);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([
          widget.location,
          widget.target,
          ...?widget.route?.points,
        ]),
        padding: EdgeInsets.fromLTRB(56, topEdge + 40, 56, bottomInset + 40),
        maxZoom: 17,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DriverMap(
            controller: _mapController,
            location: widget.location,
            isOnline: true,
            hospital: widget.hospital,
            // Starts at the ambulance, not where the route was fetched.
            route: routeAhead(
              widget.route?.points ?? const [],
              widget.location,
            ),
            destination: widget.showTargetDot ? widget.target : null,
            onMapReady: _fitAfterLayout,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              key: _topKey,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: widget.top,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(
                      child: Text(
                        DriverMap.attribution,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          shadows: [Shadow(color: Colors.white, blurRadius: 4)],
                        ),
                      ),
                    ),
                    Material(
                      color: AppColors.surface,
                      shape: const CircleBorder(),
                      elevation: 3,
                      shadowColor: Colors.black26,
                      child: IconButton(
                        onPressed: _fitRoute,
                        tooltip: 'Lihat seluruh rute',
                        icon: const Icon(
                          Icons.route_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              KeyedSubtree(key: _sheetKey, child: widget.sheet),
            ],
          ),
        ),
      ],
    );
  }
}

/// White bottom sheet with a drag handle, used by the trip screens.
class TripSheet extends StatelessWidget {
  const TripSheet({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// "HH:mm" in local time.
String formatClock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// Holds a route's starting point steady while GPS updates stream in, so the
/// route is only re-fetched after the driver has moved a meaningful distance.
mixin StableRouteOrigin<T extends StatefulWidget> on State<T> {
  static const _refreshAfterMeters = 300;

  LatLng? _origin;

  LatLng routeOrigin(LatLng live) {
    final origin = _origin;
    if (origin == null ||
        const Distance().as(LengthUnit.Meter, origin, live) >
            _refreshAfterMeters) {
      _origin = live;
    }
    return _origin!;
  }
}
