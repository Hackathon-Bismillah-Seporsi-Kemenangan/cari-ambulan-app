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

class AssignedDriver {
  const AssignedDriver({
    required this.id,
    required this.name,
    this.phone,
    this.licenseNumber,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String? phone;
  final String? licenseNumber;
  final double? latitude;
  final double? longitude;

  factory AssignedDriver.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    return AssignedDriver(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Pengemudi Ambulans',
      phone: json['phone'] as String?,
      licenseNumber: json['license_number'] as String?,
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
    );
  }
}

class AmbulanceInfo {
  const AmbulanceInfo({
    required this.id,
    required this.plateNumber,
    this.vehicleModel,
    this.ambulanceType,
  });

  final String id;
  final String plateNumber;
  final String? vehicleModel;
  final String? ambulanceType;

  factory AmbulanceInfo.fromJson(Map<String, dynamic> json) {
    return AmbulanceInfo(
      id: json['id'] as String? ?? '',
      plateNumber: json['plate_number'] as String? ?? 'Ambulans',
      vehicleModel: json['vehicle_model'] as String?,
      ambulanceType: json['ambulance_type'] as String?,
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
    this.assignedDriver,
    this.ambulance,
  });

  final String id;
  final String requestCode;
  final EmergencyRequestStatus status;
  final EmergencyLocation pickup;
  final bool isForSelf;
  final String? emergencyType;
  final String? severityLevel;
  final String? patientNotes;
  final int searchRadiusKm;
  final bool isExhausted;
  final AssignedDriver? assignedDriver;
  final AmbulanceInfo? ambulance;

  factory EmergencyRequestModel.fromJson(Map<String, dynamic> json) {
    final pickupMap = json['pickup'] as Map<String, dynamic>? ?? {};
    final searchMap = json['search'] as Map<String, dynamic>? ?? {};
    final driverMap = json['assigned_driver'] as Map<String, dynamic>?;
    final ambMap = json['ambulance'] as Map<String, dynamic>?;

    return EmergencyRequestModel(
      id: json['id'] as String? ?? '',
      requestCode: json['request_code'] as String? ?? '',
      status: EmergencyRequestStatus.fromString(json['status'] as String?),
      pickup: EmergencyLocation.fromJson(pickupMap),
      isForSelf: json['is_for_self'] as bool? ?? true,
      emergencyType: json['emergency_type'] as String?,
      severityLevel: json['severity_level'] as String?,
      patientNotes: json['patient_notes'] as String?,
      searchRadiusKm: (searchMap['radius_km'] as num?)?.toInt() ?? 3,
      isExhausted: searchMap['is_exhausted'] as bool? ?? false,
      assignedDriver: driverMap != null ? AssignedDriver.fromJson(driverMap) : null,
      ambulance: ambMap != null ? AmbulanceInfo.fromJson(ambMap) : null,
    );
  }
}

