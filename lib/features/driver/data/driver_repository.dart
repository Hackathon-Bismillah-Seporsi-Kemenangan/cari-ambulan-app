import '../../emergency/domain/emergency_models.dart';
import '../domain/dispatch_offer_model.dart';
import '../domain/driver_models.dart';

abstract class DriverRepository {
  Future<DriverProfile> fetchProfile();

  Future<DriverProfile> setAvailability(
    DriverAvailability availability, {
    double? latitude,
    double? longitude,
  });

  Future<void> sendLocation(double latitude, double longitude);

  /// Fetch incoming emergency dispatch offer for this driver.
  Future<DispatchOfferModel?> getCurrentOffer();

  /// Accept the offered emergency. The trip starts en route to the pickup.
  Future<EmergencyRequestModel> acceptRequest(String requestId);

  /// Decline the offered emergency so dispatch tries the next driver.
  Future<void> declineRequest(String requestId);

  /// Fetch the trip this driver is serving (or one the patient cancelled
  /// recently), so it can be resumed after a restart.
  Future<EmergencyRequestModel?> getActiveTrip();

  /// The ambulance reached the pickup.
  Future<EmergencyRequestModel> markArrived(String requestId);

  /// Patient on board; the server assigns the nearest hospital.
  Future<EmergencyRequestModel> startToHospital(String requestId);

  /// Patient handed over to the IGD; the driver is back online.
  Future<EmergencyRequestModel> completeTrip(String requestId);
}
