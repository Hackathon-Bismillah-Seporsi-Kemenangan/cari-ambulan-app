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

  /// Accept an emergency offer.
  Future<EmergencyRequestModel> acceptOffer(int offerId);

  /// Decline an emergency offer.
  Future<void> declineOffer(int offerId);

  /// Fetch active emergency trip currently being served by this driver.
  Future<EmergencyRequestModel?> getActiveTrip();

  /// Progress the status of the current emergency trip.
  Future<EmergencyRequestModel> updateTripStatus(String status);
}

