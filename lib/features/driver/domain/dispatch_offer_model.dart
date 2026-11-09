class DispatchOfferModel {
  const DispatchOfferModel({
    required this.id,
    required this.emergencyRequestId,
    required this.requestCode,
    required this.status,
    required this.distanceKm,
    required this.secondsRemaining,
    this.emergencyType,
    this.severityLevel,
    this.patientNotes,
    required this.pickupAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.patientName,
    this.patientPhone,
    this.bloodType,
    this.etaMinutes,
    this.nearestHospitalName,
    this.offeredAt,
    this.expiresAt,
  });

  final int id;
  final String emergencyRequestId;
  final String requestCode;
  final String status;
  final double distanceKm;
  final int secondsRemaining;
  final String? emergencyType;
  final String? severityLevel;
  final String? patientNotes;
  final String pickupAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final String patientName;
  final String? patientPhone;
  final String? bloodType;
  final int? etaMinutes;
  final String? nearestHospitalName;
  final DateTime? offeredAt;
  final DateTime? expiresAt;

  /// Full time the driver has to answer, 30 s on the server.
  Duration get offerWindow {
    final offered = offeredAt;
    final expires = expiresAt;
    if (offered == null || expires == null || !expires.isAfter(offered)) {
      return const Duration(seconds: 30);
    }
    return expires.difference(offered);
  }

  /// Parses `GET /driver/offers/current`: offer fields at the top, the
  /// emergency itself nested under `request`.
  factory DispatchOfferModel.fromJson(Map<String, dynamic> json) {
    final request = json['request'] as Map<String, dynamic>? ?? {};
    final pickup = request['pickup'] as Map<String, dynamic>? ?? {};
    final reporter = request['reporter'] as Map<String, dynamic>? ?? {};
    final medical = request['medical'] as Map<String, dynamic>? ?? {};
    final hospital = json['nearest_hospital'] as Map<String, dynamic>?;
    final bloodType = medical['blood_type'] as String?;

    return DispatchOfferModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      emergencyRequestId: '${request['id'] ?? ''}',
      requestCode: request['code'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      secondsRemaining: (json['seconds_remaining'] as num?)?.toInt() ?? 30,
      emergencyType: request['emergency_type'] as String?,
      severityLevel: request['severity_level'] as String?,
      patientNotes: request['patient_notes'] as String?,
      pickupAddress: pickup['address'] as String? ?? 'Lokasi penjemputan',
      pickupLatitude: (pickup['latitude'] as num?)?.toDouble() ?? 0.0,
      pickupLongitude: (pickup['longitude'] as num?)?.toDouble() ?? 0.0,
      patientName: reporter['name'] as String? ?? 'Pasien Darurat',
      patientPhone: reporter['phone'] as String?,
      bloodType: bloodType == 'unknown' ? null : bloodType,
      etaMinutes: (json['eta_minutes'] as num?)?.toInt(),
      nearestHospitalName: hospital?['name'] as String?,
      offeredAt: json['offered_at'] != null ? DateTime.tryParse(json['offered_at'] as String) : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) : null,
    );
  }
}
