import 'package:latlong2/latlong.dart';

import '../../call/domain/call_models.dart';
import '../domain/user_models.dart';

/// Backend access for the user (patient / caller) app.
abstract interface class UserRepository {
  /// Null when no ambulance is online nearby.
  Future<NearestAmbulance?> fetchNearestAmbulance(LatLng from);

  /// Street address for the pickup card, e.g. "Jl. Sudirman No. 21".
  Future<String?> addressOf(LatLng point);

  /// Name of the hospital nearest to [from], shown as "Tujuan".
  Future<String?> nearestHospitalName(LatLng from);

  /// Sends the emergency and starts looking for a driver.
  Future<EmergencySearch> createEmergency({
    required LatLng pickup,
    required String address,
    required bool forSelf,
    required EmergencyType type,
  });

  /// The user's request that is still searching or under way, if any.
  Future<EmergencySearch?> fetchOpenEmergency();

  /// Polls the request while it is listened to.
  Stream<EmergencySearch> watchEmergency(String id);

  /// "Batalkan Pencarian", or cancelling an ambulance already on its way
  /// with one of the dialog's [reason]s.
  Future<EmergencySearch> cancelEmergency(String id, {String? reason});

  /// Widens the search now ("5 km" tapped on the radius picker).
  Future<EmergencySearch> expandSearchRadius(String id, double radiusKm);

  /// "Cari Lagi" after nobody accepted: searches the full radius again.
  Future<EmergencySearch> retrySearch(String id);

  /// Rings the driver in their app ("Telepon" without a phone number).
  Future<void> callDriver(String requestId);

  /// The driver's call ringing for this user (null when none), re-checked
  /// for as long as it is listened to.
  Stream<IncomingCall?> watchIncomingCall();

  /// Past requests for Riwayat, newest first.
  Future<List<EmergencyHistoryItem>> fetchHistory();

  /// The Medical ID; [Synced.synced] is false when only the copy on this
  /// phone could be read.
  Future<Synced<MedicalProfile>> fetchMedicalProfile();

  /// Saves on the phone and the server; returns whether the server has it.
  Future<bool> saveMedicalProfile(MedicalProfile profile);

  Future<Synced<List<SavedAddress>>> fetchAddresses();

  /// Returns whether the server has it.
  Future<bool> addAddress(SavedAddress address);

  /// Edits the account; returns the updated name and phone.
  Future<({String fullName, String? phone})> updateProfile({
    required String fullName,
    required String phone,
  });
}

/// A value and whether it came from the server (rather than only the copy
/// saved on this phone).
typedef Synced<T> = ({T value, bool synced});
