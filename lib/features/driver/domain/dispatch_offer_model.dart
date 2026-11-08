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
    this.offeredAt,
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
  final DateTime? offeredAt;

  factory DispatchOfferModel.fromJson(Map<String, dynamic> json) {
    final pickup = json['pickup'] as Map<String, dynamic>? ?? {};
    final patient = json['patient'] as Map<String, dynamic>? ?? {};

    return DispatchOfferModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      emergencyRequestId: json['emergency_request_id'] as String? ?? '',
      requestCode: json['request_code'] as String? ?? '',
      status: json['status'] as String? ?? 'offered',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      secondsRemaining: (json['seconds_remaining'] as num?)?.toInt() ?? 30,
      emergencyType: json['emergency_type'] as String?,
      severityLevel: json['severity_level'] as String?,
      patientNotes: json['patient_notes'] as String?,
      pickupAddress: pickup['address'] as String? ?? 'Lokasi penjemputan',
      pickupLatitude: (pickup['latitude'] as num?)?.toDouble() ?? 0.0,
      pickupLongitude: (pickup['longitude'] as num?)?.toDouble() ?? 0.0,
      patientName: patient['name'] as String? ?? 'Pasien Darurat',
      patientPhone: patient['phone'] as String?,
      offeredAt: json['offered_at'] != null ? DateTime.tryParse(json['offered_at'] as String) : null,
    );
  }
}

