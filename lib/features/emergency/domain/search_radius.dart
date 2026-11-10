/// How far the search for a driver reaches: it starts close and widens
/// every [stepSeconds] while nobody has accepted, up to [maxKm].
///
/// Mirrors the server (`EmergencyRequest::RADIUS_STEPS` and
/// `RADIUS_EXPAND_SECONDS`), which does the actual widening; keep the two in
/// step or the screen shows a different radius than the one searched.
abstract final class SearchRadius {
  static const stepsKm = <double>[3, 5, 10, 15, 25];
  static const stepSeconds = 20;

  static double get maxKm => stepsKm.last;

  /// Index of the step [km] falls in.
  static int stepOf(double km) {
    final index = stepsKm.lastIndexWhere((step) => step <= km);
    return index < 0 ? 0 : index;
  }

  /// "3 km", "2.5 km", with a non-breaking space so it never wraps apart.
  static String label(double km) =>
      '${km == km.roundToDouble() ? km.round() : km} km';
}
