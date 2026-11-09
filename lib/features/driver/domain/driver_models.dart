enum DriverAvailability {
  offline,
  online,
  busy;

  static DriverAvailability parse(String? value) {
    switch (value?.toLowerCase()) {
      case 'online':
        return DriverAvailability.online;
      case 'busy':
        return DriverAvailability.busy;
      default:
        return DriverAvailability.offline;
    }
  }
}

class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.name,
    required this.vehiclePlate,
    required this.vehicleType,
    this.phone,
    this.licenseNumber,
    this.hospitalName,
    this.currentLatitude,
    this.currentLongitude,
    this.availabilityStatus = DriverAvailability.offline,
    this.completedTripsToday,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'] as Map<String, dynamic>?;
    final hospital = json['hospital'] as Map<String, dynamic>?;
    final location = json['location'] as Map<String, dynamic>?;

    return DriverProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      licenseNumber: json['license_number'] as String?,
      vehiclePlate: vehicle?['plate_number'] as String? ?? '–',
      vehicleType: vehicle?['vehicle_type'] as String? ?? 'Ambulans ALS',
      hospitalName: hospital?['name'] as String?,
      currentLatitude: (location?['latitude'] as num?)?.toDouble(),
      currentLongitude: (location?['longitude'] as num?)?.toDouble(),
      availabilityStatus: DriverAvailability.parse(json['availability_status'] as String?),
    );
  }

  final String id;
  final String name;
  final String vehiclePlate;
  final String vehicleType;
  final String? phone;
  final String? licenseNumber;
  final String? hospitalName;
  final double? currentLatitude;
  final double? currentLongitude;
  final DriverAvailability availabilityStatus;

  /// Sent beside the profile by `GET driver/profile` only; null elsewhere.
  final int? completedTripsToday;

  bool get isOnline => availabilityStatus == DriverAvailability.online;
  bool get isBusy => availabilityStatus == DriverAvailability.busy;
  bool get isOffline => availabilityStatus == DriverAvailability.offline;

  DriverProfile copyWith({
    String? id,
    String? name,
    String? vehiclePlate,
    String? vehicleType,
    String? phone,
    String? licenseNumber,
    String? hospitalName,
    double? currentLatitude,
    double? currentLongitude,
    DriverAvailability? availabilityStatus,
    int? completedTripsToday,
  }) {
    return DriverProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleType: vehicleType ?? this.vehicleType,
      phone: phone ?? this.phone,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      hospitalName: hospitalName ?? this.hospitalName,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      completedTripsToday: completedTripsToday ?? this.completedTripsToday,
    );
  }
}

/// A finished order in the driver's "Riwayat", from `GET driver/trips`.
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
        value is String ? DateTime.tryParse(value)?.toLocal() : null;

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

