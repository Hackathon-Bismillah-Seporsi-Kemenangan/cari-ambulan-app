import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/logging/app_log.dart';
import '../domain/route_models.dart';

/// Turn-by-turn driving routes.
abstract interface class RoutingRepository {
  Future<DriveRoute> fetchRoute(LatLng from, LatLng to);
}

/// Routes from OSRM (free, no API key).
///
/// The public servers are fine for development but have no uptime guarantee
/// and a fair-use limit; self-host OSRM (or switch providers) before launch.
/// Tries each of [baseUrls] in turn, then falls back to a straight-line
/// estimate.
class OsrmRoutingRepository implements RoutingRepository {
  OsrmRoutingRepository({
    http.Client? client,
    this.baseUrls = const [
      'https://router.project-osrm.org/route/v1/driving',
      'https://routing.openstreetmap.de/routed-car/route/v1/driving',
    ],
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final List<String> baseUrls;

  /// Average ambulance speed in city traffic, for the fallback estimate.
  static const _fallbackKmh = 25.0;

  /// Mobile data to the (European) servers can be slow; a straight line is
  /// worse than waiting a little longer.
  static const _timeout = Duration(seconds: 15);

  @override
  Future<DriveRoute> fetchRoute(LatLng from, LatLng to) async {
    for (final baseUrl in baseUrls) {
      final route = await _fetch(baseUrl, from, to);
      if (route != null) return route;
    }
    AppLog.warn('Route', 'No route server answered; drawing a straight line');
    return _straightLine(from, to);
  }

  Future<DriveRoute?> _fetch(String baseUrl, LatLng from, LatLng to) async {
    final uri = Uri.parse(
      '$baseUrl/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson&steps=true',
    );
    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        AppLog.warn('Route', '${uri.host}: HTTP ${response.statusCode}');
        return null;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (body['code'] != 'Ok' || routes == null || routes.isEmpty) {
        AppLog.warn('Route', '${uri.host}: ${body['code']}');
        return null;
      }
      final route = _parseRoute(routes.first as Map<String, dynamic>);
      AppLog.info(
        'Route',
        '${uri.host}: ${(route.distanceMeters / 1000).toStringAsFixed(1)} km'
            ' · ${route.duration.inMinutes} min · ${route.points.length} points',
      );
      return route;
    } catch (e) {
      AppLog.warn('Route', '${uri.host} failed', e);
      return null;
    }
  }

  DriveRoute _parseRoute(Map<String, dynamic> route) {
    final coordinates = (route['geometry']['coordinates'] as List)
        .cast<List<dynamic>>();
    final legs = (route['legs'] as List).cast<Map<String, dynamic>>();
    final steps = [
      for (final leg in legs)
        for (final step in (leg['steps'] as List).cast<Map<String, dynamic>>())
          _parseStep(step),
    ];

    return DriveRoute(
      points: [
        for (final c in coordinates)
          LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ],
      distanceMeters: (route['distance'] as num).toDouble(),
      duration: Duration(seconds: (route['duration'] as num).round()),
      steps: steps,
    );
  }

  RouteStep _parseStep(Map<String, dynamic> step) {
    final maneuver = step['maneuver'] as Map<String, dynamic>;
    final location = (maneuver['location'] as List).cast<num>();
    return RouteStep(
      maneuver: _maneuver(
        maneuver['type'] as String?,
        maneuver['modifier'] as String?,
      ),
      streetName: (step['name'] as String?) ?? '',
      distanceMeters: (step['distance'] as num).toDouble(),
      location: LatLng(location[1].toDouble(), location[0].toDouble()),
    );
  }

  // https://project-osrm.org/docs/v5.24.0/api/#stepmaneuver-object
  Maneuver _maneuver(String? type, String? modifier) {
    switch (type) {
      case 'depart':
        return Maneuver.depart;
      case 'arrive':
        return Maneuver.arrive;
      case 'roundabout' || 'rotary' || 'roundabout turn':
        return Maneuver.roundabout;
    }
    return switch (modifier) {
      'slight left' => Maneuver.slightLeft,
      'left' => Maneuver.left,
      'sharp left' => Maneuver.sharpLeft,
      'slight right' => Maneuver.slightRight,
      'right' => Maneuver.right,
      'sharp right' => Maneuver.sharpRight,
      'uturn' => Maneuver.uTurn,
      _ => Maneuver.straight,
    };
  }

  DriveRoute _straightLine(LatLng from, LatLng to) {
    final meters = const Distance().as(LengthUnit.Meter, from, to);
    return DriveRoute(
      points: [from, to],
      distanceMeters: meters,
      duration: Duration(
        seconds: (meters / 1000 / _fallbackKmh * 3600).round(),
      ),
      steps: [
        RouteStep(
          maneuver: Maneuver.depart,
          streetName: '',
          distanceMeters: meters,
          location: from,
        ),
        RouteStep(
          maneuver: Maneuver.arrive,
          streetName: '',
          distanceMeters: 0,
          location: to,
        ),
      ],
      isEstimate: true,
    );
  }
}
