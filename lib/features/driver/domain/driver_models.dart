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
    );
  }
}

