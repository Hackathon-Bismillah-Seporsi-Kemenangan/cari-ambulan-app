import 'package:latlong2/latlong.dart';

import '../domain/driver_models.dart';

/// Contract between the Driver UI and the backend.
///
/// The UI only talks to this interface: [ApiDriverRepository] talks to the
/// Laravel API, [MockDriverRepository] fakes it for tests and offline demos.
abstract interface class DriverRepository {
  Future<DriverProfile> fetchProfile();

  Future<DriverTodayStats> fetchTodayStats();

  Future<DriverAvailability> fetchAvailability();

  /// Finished orders (completed or cancelled), newest first.
  Future<List<DriverTripHistoryItem>> fetchTripHistory();

  /// Saves the account's name and phone; returns them as stored.
  Future<({String fullName, String? phone})> updateAccount({
    required String fullName,
    required String phone,
  });

  /// Saves the new availability and current location.
  Future<void> setAvailability(
    DriverAvailability availability,
    LatLng location,
  );

  /// Nearest hospital with a known location.
  Future<NearbyHospital?> fetchNearestHospital(LatLng from);

  /// Emits the driver's current GPS position.
  Stream<LatLng> watchLocation();

  /// Sends a GPS fix so dispatch can find the driver and the reporter can
  /// track the ambulance.
  Future<void> reportLocation(LatLng location);

  /// The order in progress, so the app can resume it after a restart. Null
  /// once it was cancelled or completed.
  Future<ActiveTrip?> fetchActiveTrip();

  /// Whether the order [requestId] is still in progress on the server.
  Future<RemoteTripStatus> checkTrip(String requestId);

  /// Emergency orders offered to this driver while online.
  Stream<EmergencyRequest> watchIncomingRequests();

  /// Claims the order. Throws if it expired or another driver took it.
  Future<void> acceptRequest(String requestId);

  /// Tells dispatch and the reporter the ambulance reached the pickup.
  Future<void> markArrivedAtPatient(String requestId);

  /// Patient is on board. Dispatch picks the destination hospital and alerts
  /// its IGD; returns that assignment.
  Future<HospitalAssignment> startToHospital(String requestId, LatLng from);

  /// Patient handed over to the IGD; closes the order and puts the driver
  /// back online.
  Future<void> completeHandover(String requestId);

  /// Declines the order so dispatch can offer it to the next driver.
  Future<void> declineRequest(String requestId);

  /// The reporter's call ringing or in progress on the active order (null
  /// when there is none), re-checked for as long as it is listened to.
  Stream<TripCall?> watchTripCall();

  /// Picks up the reporter's call. Throws if it already stopped ringing.
  Future<TripCall> answerCall(String callId);

  Future<void> declineCall(String callId);

  /// Hangs up an answered call.
  Future<void> endCall(String callId);
}
