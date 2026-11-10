import 'package:latlong2/latlong.dart';

enum EmergencyRequestStatus {
  searchingDriver('searching_driver', 'Mencari Ambulans...'),
  driverAssigned('driver_assigned', 'Ambulans Ditugaskan'),
  enRouteToPickup('en_route_to_pickup', 'Ambulans Menuju Lokasi'),
  arriveAtPickup('arrive_at_pickup', 'Ambulans Tiba di Lokasi'),
  enRouteToHospital('en_route_to_hospital', 'Menuju Rumah Sakit'),
  completed('completed', 'Selesai'),
  cancelled('cancelled', 'Dibatalkan');

  const EmergencyRequestStatus(this.value, this.label);

  final String value;
  final String label;

  static EmergencyRequestStatus fromString(String? val) {
    for (final s in EmergencyRequestStatus.values) {
      if (s.value == val) return s;
    }
    return EmergencyRequestStatus.searchingDriver;
  }

  bool get isSearching => this == EmergencyRequestStatus.searchingDriver;
  bool get isClosed =>
      this == EmergencyRequestStatus.completed ||
      this == EmergencyRequestStatus.cancelled;
  bool get isActiveTrip =>
      this == EmergencyRequestStatus.driverAssigned ||
      this == EmergencyRequestStatus.enRouteToPickup ||
      this == EmergencyRequestStatus.arriveAtPickup ||
      this == EmergencyRequestStatus.enRouteToHospital;
}

class EmergencyLocation {
  const EmergencyLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final double latitude;
  final double longitude;
  final String address;

  factory EmergencyLocation.fromJson(Map<String, dynamic> json) {
    return EmergencyLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String? ?? 'Lokasi penjemputan',
    );
  }
}

/// The driver serving the request, from `driver` in the search view.
class AssignedDriver {
  const AssignedDriver({required this.name, this.phone, this.photoUrl});

  final String name;
  final String? phone;
  final String? photoUrl;

  factory AssignedDriver.fromJson(Map<String, dynamic> json) {
    return AssignedDriver(
      name: json['name'] as String? ?? 'Driver ambulans',
      phone: json['phone'] as String?,
      photoUrl: json['photo_url'] as String?,
    );
  }
}

/// The ambulance on its way, from `ambulance` in the search view. Its
/// position is only sent while it serves this request.
class AmbulanceInfo {
  const AmbulanceInfo({
    this.plateNumber,
    this.vehicleType,
    this.latitude,
    this.longitude,
    this.locationAgeSeconds,
  });

  final String? plateNumber;

  /// e.g. "Ambulans ALS".
  final String? vehicleType;
  final double? latitude;
  final double? longitude;

  /// How long ago the driver last reported that position (server clock).
  final int? locationAgeSeconds;

  /// After this long without a position, the driver has gone quiet (phone
  /// off, no signal) and the marker is stale, not moving.
  static const silentAfterSeconds = 40;

  LatLng? get location => latitude == null || longitude == null
      ? null
      : LatLng(latitude!, longitude!);

  bool get isSilent =>
      location != null && (locationAgeSeconds ?? 0) >= silentAfterSeconds;

  /// "ALS · Gawat Darurat" chip next to the plate.
  String? get vehicleLabel {
    final type = vehicleType;
    if (type == null) return null;
    if (type.contains('ALS')) return 'ALS · Gawat Darurat';
    if (type.contains('BLS')) return 'BLS · Dasar';
    return type;
  }

  factory AmbulanceInfo.fromJson(Map<String, dynamic> json) {
    return AmbulanceInfo(
      plateNumber: json['plate_number'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationAgeSeconds: (json['location_age_seconds'] as num?)?.toInt(),
    );
  }
}

/// Destination hospital, assigned when the patient is on board. Its IGD has
/// already been alerted.
class HospitalInfo {
  const HospitalInfo({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.emergencyPhone,
    this.ambulanceEntrance,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? emergencyPhone;

  /// Where the ambulance should pull in, e.g. "Gerbang B".
  final String? ambulanceEntrance;

  factory HospitalInfo.fromJson(Map<String, dynamic> json) {
    return HospitalInfo(
      name: json['name'] as String? ?? 'Rumah Sakit',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String?,
      emergencyPhone: json['emergency_phone'] as String?,
      ambulanceEntrance: json['ambulance_entrance'] as String?,
    );
  }
}

class EmergencyRequestModel {
  const EmergencyRequestModel({
    required this.id,
    required this.requestCode,
    required this.status,
    required this.pickup,
    this.isForSelf = true,
    this.emergencyType,
    this.severityLevel,
    this.patientNotes,
    this.searchRadiusKm = 3,
    this.isExhausted = false,
    this.driversContacted = 0,
    this.radiusExpandsInSeconds,
    this.nearbyAmbulances = const [],
    this.assignedDriver,
    this.ambulance,
    this.etaMinutes,
    this.etaDistanceKm,
    this.reporterName,
    this.reporterPhone,
    this.bloodType,
    this.isHighPriority = false,
    this.hospital,
    this.hospitalPreparation,
    this.requestedAt,
    this.acceptedAt,
    this.arrivedAtPickupAt,
    this.pickedUpAt,
  });

  final String id;
  final String requestCode;
  final EmergencyRequestStatus status;
  final EmergencyLocation pickup;
  final bool isForSelf;
  final String? emergencyType;
  final String? severityLevel;
  final String? patientNotes;
  /// Radius the server is offering the request in now.
  final double searchRadiusKm;

  /// Nobody accepted within the largest radius.
  final bool isExhausted;

  /// Drivers the request has been offered to so far.
  final int driversContacted;

  /// Seconds until the server widens the radius; 0 at the largest one.
  final int? radiusExpandsInSeconds;

  /// Free ambulances around the pickup, rounded to ~100 m.
  final List<LatLng> nearbyAmbulances;
  final AssignedDriver? assignedDriver;
  final AmbulanceInfo? ambulance;

  /// Server's straight-line estimate to where the ambulance heads now.
  final int? etaMinutes;
  final double? etaDistanceKm;

  /// Person who placed the call (the patient or a relative).
  final String? reporterName;
  final String? reporterPhone;

  /// From the reporter's Medical ID, when they called for themselves.
  final String? bloodType;
  final bool isHighPriority;
  final HospitalInfo? hospital;

  /// What the IGD is preparing, e.g. "IGD menyiapkan tim jantung."
  final String? hospitalPreparation;
  final DateTime? requestedAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAtPickupAt;
  final DateTime? pickedUpAt;

  factory EmergencyRequestModel.fromJson(Map<String, dynamic> json) {
    final pickupMap = json['pickup'] as Map<String, dynamic>? ?? {};
    final driverMap = json['driver'] as Map<String, dynamic>?;
    final etaMap = json['eta'] as Map<String, dynamic>?;
    final ambMap = json['ambulance'] as Map<String, dynamic>?;
    final reporterMap = json['reporter'] as Map<String, dynamic>?;
    final medicalMap = json['medical'] as Map<String, dynamic>?;
    final hospitalMap = json['hospital'] as Map<String, dynamic>?;
    final bloodType = medicalMap?['blood_type'] as String?;
    DateTime? time(Object? value) =>
        value is String ? DateTime.tryParse(value)?.toLocal() : null;

    return EmergencyRequestModel(
      id: json['id'] as String? ?? '',
      requestCode: (json['code'] ?? json['request_code']) as String? ?? '',
      status: EmergencyRequestStatus.fromString(json['status'] as String?),
      pickup: EmergencyLocation.fromJson(pickupMap),
      isForSelf: json['is_for_self'] as bool? ?? true,
      emergencyType: json['emergency_type'] as String?,
      severityLevel: json['severity_level'] as String?,
      patientNotes: json['patient_notes'] as String?,
      searchRadiusKm: (json['search_radius_km'] as num?)?.toDouble() ?? 3,
      isExhausted: json['search_exhausted'] as bool? ?? false,
      driversContacted: (json['drivers_contacted'] as num?)?.toInt() ?? 0,
      radiusExpandsInSeconds:
          (json['radius_expands_in_seconds'] as num?)?.toInt(),
      nearbyAmbulances: [
        for (final a in json['nearby_ambulances'] as List? ?? const [])
          if (a is Map &&
              a['latitude'] is num &&
              a['longitude'] is num)
            LatLng(
              (a['latitude'] as num).toDouble(),
              (a['longitude'] as num).toDouble(),
            ),
      ],
      assignedDriver: driverMap != null ? AssignedDriver.fromJson(driverMap) : null,
      ambulance: ambMap != null ? AmbulanceInfo.fromJson(ambMap) : null,
      etaMinutes: (etaMap?['minutes'] as num?)?.toInt(),
      etaDistanceKm: (etaMap?['distance_km'] as num?)?.toDouble(),
      reporterName: reporterMap?['name'] as String?,
      reporterPhone: reporterMap?['phone'] as String?,
      bloodType: bloodType == 'unknown' ? null : bloodType,
      isHighPriority: json['is_high_priority'] as bool? ?? false,
      hospital: hospitalMap != null ? HospitalInfo.fromJson(hospitalMap) : null,
      hospitalPreparation: json['hospital_preparation'] as String?,
      requestedAt: time(json['request_at']),
      acceptedAt: time(json['accepted_at']),
      arrivedAtPickupAt: time(json['arrived_at_pickup_at']),
      pickedUpAt: time(json['picked_up_at']),
    );
  }
}

