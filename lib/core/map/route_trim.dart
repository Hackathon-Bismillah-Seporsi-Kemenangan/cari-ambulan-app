import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// The part of [route] still ahead of [position], starting exactly at
/// [position].
///
/// Routes are only re-fetched every few hundred meters, so the line would
/// otherwise start where the ambulance was when it was fetched and trail
/// behind its icon. The ambulance is matched to the nearest segment of the
/// route; everything before that is dropped.
List<LatLng> routeAhead(List<LatLng> route, LatLng position) {
  if (route.length < 2) return route;

  // Meters on a flat plane around the position: plenty accurate over a city.
  final metersPerLat = 111320.0;
  final metersPerLng = 111320.0 * math.cos(position.latitude * math.pi / 180);
  (double, double) toPlane(LatLng p) => (
    (p.longitude - position.longitude) * metersPerLng,
    (p.latitude - position.latitude) * metersPerLat,
  );

  var nearestSegment = 0;
  var nearestDistance = double.infinity;
  for (var i = 0; i < route.length - 1; i++) {
    final (ax, ay) = toPlane(route[i]);
    final (bx, by) = toPlane(route[i + 1]);
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    // Where along a→b the position falls, kept on the segment.
    final t = lengthSquared == 0
        ? 0.0
        : ((-ax * dx - ay * dy) / lengthSquared).clamp(0.0, 1.0);
    final px = ax + t * dx;
    final py = ay + t * dy;
    final distance = px * px + py * py;
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearestSegment = i;
    }
  }

  return [position, ...route.sublist(nearestSegment + 1)];
}
