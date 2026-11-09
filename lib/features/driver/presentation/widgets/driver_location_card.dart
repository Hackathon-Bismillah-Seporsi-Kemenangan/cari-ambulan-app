import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'driver_map.dart';

/// The driver's position on a map, kept centered as new GPS fixes arrive.
class DriverLocationCard extends StatefulWidget {
  const DriverLocationCard({
    super.key,
    required this.location,
    required this.isOnline,
  });

  final LatLng location;
  final bool isOnline;

  @override
  State<DriverLocationCard> createState() => _DriverLocationCardState();
}

class _DriverLocationCardState extends State<DriverLocationCard> {
  final _controller = MapController();
  var _isReady = false;

  @override
  void didUpdateWidget(DriverLocationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The controller can't move the camera before the map has laid out.
    if (_isReady && oldWidget.location != widget.location) {
      _controller.move(widget.location, _controller.camera.zoom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DriverMap(
        controller: _controller,
        location: widget.location,
        isOnline: widget.isOnline,
        onMapReady: () => _isReady = true,
      ),
    );
  }
}
