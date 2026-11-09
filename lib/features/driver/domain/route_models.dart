import 'package:latlong2/latlong.dart';

/// Direction of a turn, simplified from OSRM's maneuver type + modifier.
enum Maneuver {
  depart,
  straight,
  slightLeft,
  left,
  sharpLeft,
  slightRight,
  right,
  sharpRight,
  uTurn,
  roundabout,
  arrive,
}

class RouteStep {
  const RouteStep({
    required this.maneuver,
    required this.streetName,
    required this.distanceMeters,
    required this.location,
  });

  final Maneuver maneuver;

  /// Empty when the road has no name.
  final String streetName;

  /// Distance driven on this step, until the next maneuver.
  final double distanceMeters;

  /// Where the maneuver happens.
  final LatLng location;

  /// Spoken-style instruction, e.g. "Belok kanan ke Jl. Thamrin".
  String get instruction {
    final action = switch (maneuver) {
      Maneuver.depart => 'Mulai perjalanan',
      Maneuver.straight => 'Lurus',
      Maneuver.slightLeft => 'Agak ke kiri',
      Maneuver.left => 'Belok kiri',
      Maneuver.sharpLeft => 'Belok tajam ke kiri',
      Maneuver.slightRight => 'Agak ke kanan',
      Maneuver.right => 'Belok kanan',
      Maneuver.sharpRight => 'Belok tajam ke kanan',
      Maneuver.uTurn => 'Putar balik',
      Maneuver.roundabout => 'Masuk bundaran',
      Maneuver.arrive => 'Tiba di tujuan',
    };
    if (maneuver == Maneuver.arrive || streetName.isEmpty) return action;
    return '$action ke $streetName';
  }
}

class DriveRoute {
  const DriveRoute({
    required this.points,
    required this.distanceMeters,
    required this.duration,
    required this.steps,
    this.isEstimate = false,
  });

  /// Polyline from the driver to the destination.
  final List<LatLng> points;
  final double distanceMeters;
  final Duration duration;
  final List<RouteStep> steps;

  /// True when routing failed and this is a straight-line guess.
  final bool isEstimate;

  /// The next turn to show in the banner (the first step after departing).
  RouteStep? get nextManeuver => steps.length > 1 ? steps[1] : null;

  /// Distance until [nextManeuver].
  double get distanceToNextManeuver =>
      steps.isEmpty ? distanceMeters : steps.first.distanceMeters;
}
