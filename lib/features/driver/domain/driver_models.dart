import 'package:latlong2/latlong.dart';

/// Mirrors the planned `driver_status` table.
enum DriverAvailability { offline, online, busy }

class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.name,
    required this.vehiclePlate,
    required this.vehicleType,
    this.phone,
    this.licenseNumber,
    this.hospitalName,
  });

  final String id;
  final String name;
  final String vehiclePlate;

  /// e.g. "Ambulans ALS" / "Ambulans BLS".
  final String vehicleType;
  final String? phone;

  /// Driving licence (SIM) number.
  final String? licenseNumber;

  /// The hospital this ambulance belongs to, if any.
  final String? hospitalName;
}

class DriverTodayStats {
  const DriverTodayStats({
    required this.completedTrips,
    this.totalCompletedTrips,
    this.rating,
  });

  final int completedTrips;

  /// All trips completed so far; null when the server doesn't say.
  final int? totalCompletedTrips;

  /// Not tracked by the backend yet (out of MVP scope); null hides it.
  final double? rating;
}

/// A finished order in the driver's "Riwayat".
class DriverTripHistoryItem {
  const DriverTripHistoryItem({
    required this.id,
    required this.code,
    required this.status,
    required this.emergencyType,
    required this.pickupAddress,
    required this.requestedAt,
    this.patientName,
    this.hospitalName,
    this.completedAt,
    this.cancelledAt,
    this.cancelReason,
  });

  factory DriverTripHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime? time(Object? value) =>
        value is String ? DateTime.parse(value).toLocal() : null;
    return DriverTripHistoryItem(
      id: '${json['id']}',
      code: json['code'] as String? ?? '–',
      status: json['status'] as String? ?? '',
      emergencyType: json['emergency_type'] as String? ?? 'Darurat',
      pickupAddress: json['pickup_address'] as String? ?? '–',
      requestedAt: time(json['request_at']) ?? DateTime.now(),
      patientName: json['patient_name'] as String?,
      hospitalName: json['hospital_name'] as String?,
      completedAt: time(json['completed_at']),
      cancelledAt: time(json['cancelled_at']),
      cancelReason: json['cancel_reason'] as String?,
    );
  }

  final String id;
  final String code;

  /// Raw server status: "completed" or "cancelled".
  final String status;
  final String emergencyType;
  final String pickupAddress;
  final DateTime requestedAt;
  final String? patientName;
  final String? hospitalName;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;

  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
}

class NearbyHospital {
  const NearbyHospital({
    required this.name,
    required this.location,
    required this.distanceKm,
  });

  final String name;
  final LatLng location;
  final double distanceKm;
}

/// An emergency order offered to this driver, from the planned `orders`
/// table. The driver must accept before [expiresAt] or it is reassigned.
class EmergencyRequest {
  const EmergencyRequest({
    required this.id,
    required this.reporterName,
    required this.reporterPhone,
    required this.condition,
    this.symptom,
    required this.patientCount,
    required this.pickupAddress,
    required this.pickupLocation,
    required this.distanceKm,
    required this.etaMinutes,
    required this.nearestHospitalName,
    required this.offeredAt,
    required this.expiresAt,
    this.pickupDetail,
    this.bloodType,
    this.allergy,
    this.note,
    this.isHighPriority = false,
    this.requestedAt,
    this.code,
  });

  final String id;

  /// Person who placed the call (may be the patient or a relative).
  final String reporterName;
  final String reporterPhone;

  /// e.g. "Jantung".
  final String condition;

  /// e.g. "Nyeri dada". The backend only sends free-text notes, so this is
  /// usually null.
  final String? symptom;

  /// Short order code shown to the driver, e.g. "CA-B3HOZH".
  final String? code;
  final int patientCount;
  final String pickupAddress;

  /// Extra directions, e.g. "Lobby Wisma 46, lantai dasar".
  final String? pickupDetail;
  final LatLng pickupLocation;
  final double distanceKm;
  final int etaMinutes;
  final String nearestHospitalName;

  /// From the reporter's Medical ID, when shared.
  final String? bloodType;
  final String? allergy;

  /// Free-text message from the reporter.
  final String? note;

  /// Set by dispatch triage (e.g. cardiac or breathing complaints).
  final bool isHighPriority;

  /// When the reporter placed the call; null if dispatch didn't send it.
  final DateTime? requestedAt;
  final DateTime offeredAt;
  final DateTime expiresAt;

  Duration get offerWindow => expiresAt.difference(offeredAt);
}

/// Progress of the accepted order.
enum TripStage { toPatient, atPatient, toHospital }

/// What the server says about the order the driver has open.
enum RemoteTripStatus {
  /// Still in progress.
  active,

  /// The patient cancelled it.
  cancelled,

  /// Gone for another reason (completed elsewhere, or no longer assigned).
  ended,
}

/// Destination hospital chosen by dispatch, which has already alerted its
/// emergency room (IGD).
class HospitalAssignment {
  const HospitalAssignment({
    required this.hospital,
    required this.preparation,
    this.entrance,
  });

  final NearbyHospital hospital;

  /// What the IGD is preparing, e.g. "IGD menyiapkan tim jantung."
  final String preparation;

  /// Where the ambulance should pull in, e.g. "Gerbang B".
  final String? entrance;
}

/// The order this driver accepted, from pickup to hospital handover.
class ActiveTrip {
  const ActiveTrip({
    required this.request,
    required this.acceptedAt,
    this.stage = TripStage.toPatient,
    this.arrivedAt,
    this.departedToHospitalAt,
    this.hospital,
  });

  final EmergencyRequest request;
  final TripStage stage;
  final DateTime acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? departedToHospitalAt;
  final HospitalAssignment? hospital;

  ActiveTrip copyWith({
    TripStage? stage,
    DateTime? arrivedAt,
    DateTime? departedToHospitalAt,
    HospitalAssignment? hospital,
  }) {
    return ActiveTrip(
      request: request,
      acceptedAt: acceptedAt,
      stage: stage ?? this.stage,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      departedToHospitalAt: departedToHospitalAt ?? this.departedToHospitalAt,
      hospital: hospital ?? this.hospital,
    );
  }
}

enum TripCallStatus { ringing, answered }

/// A voice call from the reporter to the driver during the active order.
class TripCall {
  const TripCall({
    required this.id,
    required this.status,
    required this.callerName,
    required this.ringEndsAt,
    this.requestCode,
    this.answeredAt,
  });

  final String id;
  final TripCallStatus status;
  final String callerName;

  /// Shown as "Order #…"; older orders may not have one.
  final String? requestCode;

  /// When the call stops ringing and counts as missed.
  final DateTime ringEndsAt;
  final DateTime? answeredAt;

  bool get isRinging => status == TripCallStatus.ringing;

  TripCall answered(DateTime at) => TripCall(
    id: id,
    status: TripCallStatus.answered,
    callerName: callerName,
    ringEndsAt: ringEndsAt,
    requestCode: requestCode,
    answeredAt: at,
  );

  // Polling returns a new object every few seconds; compare by what the UI
  // shows so unchanged calls don't rebuild the trip screens.
  @override
  bool operator ==(Object other) =>
      other is TripCall && other.id == id && other.status == status;

  @override
  int get hashCode => Object.hash(id, status);
}

class DriverHomeState {
  const DriverHomeState({
    required this.profile,
    required this.availability,
    required this.location,
    required this.stats,
    this.nearestHospital,
    this.trip,
    this.cancelledTrip,
    this.isToggling = false,
  });

  final DriverProfile profile;
  final DriverAvailability availability;
  final LatLng location;
  final DriverTodayStats stats;
  final NearbyHospital? nearestHospital;

  /// The order the driver accepted and is now serving.
  final ActiveTrip? trip;

  /// The order the patient cancelled while the driver was serving it, so
  /// the screens can close and say so. Cleared by the next trip.
  final ActiveTrip? cancelledTrip;

  /// True while an online/offline request is in flight.
  final bool isToggling;

  bool get isOnline => availability != DriverAvailability.offline;

  DriverHomeState copyWith({
    DriverProfile? profile,
    DriverAvailability? availability,
    LatLng? location,
    DriverTodayStats? stats,
    NearbyHospital? nearestHospital,
    ActiveTrip? trip,
    bool clearTrip = false,
    ActiveTrip? cancelledTrip,
    bool? isToggling,
  }) {
    return DriverHomeState(
      profile: profile ?? this.profile,
      availability: availability ?? this.availability,
      location: location ?? this.location,
      stats: stats ?? this.stats,
      nearestHospital: nearestHospital ?? this.nearestHospital,
      trip: clearTrip ? null : trip ?? this.trip,
      // A new trip starts clean.
      cancelledTrip: trip != null ? null : cancelledTrip ?? this.cancelledTrip,
      isToggling: isToggling ?? this.isToggling,
    );
  }
}
