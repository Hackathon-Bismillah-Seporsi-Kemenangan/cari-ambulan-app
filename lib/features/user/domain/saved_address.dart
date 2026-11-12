import '../../emergency/domain/emergency_models.dart';

/// A place the patient saved, e.g. "Rumah", to send an ambulance there.
class SavedAddress {
  const SavedAddress({
    this.id,
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  /// Null until the server has stored it.
  final String? id;
  final String label;
  final String address;
  final double latitude;
  final double longitude;

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
    id: json['id']?.toString(),
    label: json['label'] as String? ?? 'Alamat',
    address: json['address'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
  };

  EmergencyLocation get location => EmergencyLocation(
    latitude: latitude,
    longitude: longitude,
    address: address,
  );
}
