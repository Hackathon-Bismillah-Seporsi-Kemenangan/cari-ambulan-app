/// One of the patient's past requests, for Riwayat, from
/// `GET /emergency-requests`.
class EmergencyHistoryItem {
  const EmergencyHistoryItem({
    required this.id,
    required this.code,
    required this.status,
    required this.emergencyType,
    required this.pickupAddress,
    required this.requestedAt,
    this.hospitalName,
    this.plateNumber,
    this.driverName,
    this.cancelReason,
  });

  factory EmergencyHistoryItem.fromJson(Map<String, dynamic> json) {
    final pickup = json['pickup'] as Map<String, dynamic>?;
    return EmergencyHistoryItem(
      id: '${json['id']}',
      code: json['code'] as String? ?? '–',
      status: json['status'] as String? ?? '',
      emergencyType: json['emergency_type'] as String? ?? 'Darurat',
      pickupAddress:
          (json['pickup_address'] ?? pickup?['address']) as String? ?? '–',
      requestedAt:
          DateTime.tryParse(json['request_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      hospitalName: json['hospital_name'] as String?,
      plateNumber: json['ambulance_plate'] as String?,
      driverName: json['driver_name'] as String?,
      cancelReason: json['cancel_reason'] as String?,
    );
  }

  final String id;
  final String code;

  /// Raw server status, e.g. "completed" or "cancelled".
  final String status;
  final String emergencyType;
  final String pickupAddress;
  final DateTime requestedAt;
  final String? hospitalName;
  final String? plateNumber;
  final String? driverName;
  final String? cancelReason;

  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';
}
