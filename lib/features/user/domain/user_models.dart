import 'package:latlong2/latlong.dart';

/// The closest ambulance that could take a call now, from
/// `GET /ambulances/nearest`. [location] is rounded to ~100 m.
class NearestAmbulance {
  const NearestAmbulance({
    required this.location,
    required this.distanceKm,
    required this.etaMinutes,
  });

  final LatLng location;
  final double distanceKm;
  final int etaMinutes;
}

/// What the emergency is, picked on the PANGGIL AMBULANS popup. [apiValue]
/// is the server's `emergency_type`.
enum EmergencyType {
  kecelakaan('Kecelakaan', 'Kecelakaan'),
  hentiJantung('Henti Jantung', 'Henti jantung'),
  sesakNafas('Sesak Nafas', 'Sesak napas'),
  kehamilan('Kehamilan', 'Kehamilan / persalinan'),
  lainnya('Lainnya', 'Darurat lainnya');

  const EmergencyType(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

enum EmergencySearchStatus {
  /// Offering the request to drivers one by one.
  searching,

  /// A driver accepted; the ambulance is on its way or serving the patient.
  found,
  cancelled,
  completed,
}

/// The user's own emergency request while the app looks for an ambulance,
/// from `GET /emergency-requests/{id}`.
class EmergencySearch {
  const EmergencySearch({
    required this.id,
    required this.code,
    required this.status,
    required this.emergencyType,
    required this.pickup,
    required this.pickupAddress,
    this.driversContacted = 0,
    this.nearbyAmbulances = const [],
    this.stage = TripStage.toPickup,
    this.trip,
    this.requestAt,
    this.searchRadiusKm,
    this.radiusExpandsInSeconds,
    this.searchExhausted,
  });

  final String id;
  final String code;
  final EmergencySearchStatus status;

  /// Backend value, e.g. "Henti Jantung" or "Lainnya".
  final String emergencyType;
  final LatLng pickup;
  final String pickupAddress;

  /// Drivers the request has been offered to so far.
  final int driversContacted;

  /// Free ambulances within 10 km, rounded to ~100 m.
  final List<LatLng> nearbyAmbulances;

  /// Where the trip is once [status] is [EmergencySearchStatus.found].
  final TripStage stage;

  /// The driver and ambulance on the way; null until a driver accepts, and
  /// while the server doesn't send them yet.
  final TripInfo? trip;

  /// When the request was sent; the search timer counts from here.
  final DateTime? requestAt;

  /// Radius the server is offering the request in now. Null when the server
  /// doesn't send it; the app then follows [SearchRadius.schedule].
  final double? searchRadiusKm;

  /// Seconds until the server widens the radius.
  final int? radiusExpandsInSeconds;

  /// True when nobody accepted within [SearchRadius.maxKm]. Null when the
  /// server doesn't say.
  final bool? searchExhausted;

  /// Shown as "Keluhan" on the search screen.
  String get emergencyLabel => switch (emergencyType) {
    'Henti Jantung' => 'Jantung',
    'Lainnya' => 'Darurat umum',
    final other => other,
  };
}

/// How far the search for a driver reaches: it starts close and widens
/// every [stepSeconds] while nobody has accepted, up to [maxKm].
///
/// Mirrors the server (`EmergencyRequest::RADIUS_STEPS` and
/// `RADIUS_EXPAND_SECONDS`), which does the actual widening; keep the two in
/// step or the screen shows a different radius than the one searched.
abstract final class SearchRadius {
  static const stepsKm = <double>[3, 5, 10, 15, 25];
  static const stepSeconds = 20;

  /// "1,5 mnt" or "30 dtk", for "Otomatis meluas tiap …".
  static String get stepLabel {
    if (stepSeconds < 60) return '$stepSeconds dtk';
    final minutes = stepSeconds / 60;
    final text = minutes == minutes.roundToDouble()
        ? '${minutes.round()}'
        : minutes.toStringAsFixed(1).replaceAll('.', ',');
    return '$text mnt';
  }

  static double get maxKm => stepsKm.last;

  /// Radius after [elapsed] of searching without an answer.
  static double schedule(Duration elapsed) =>
      stepsKm[(elapsed.inSeconds ~/ stepSeconds).clamp(0, stepsKm.length - 1)];

  /// Time to search all steps once, before giving up.
  static Duration get fullSearch =>
      Duration(seconds: stepSeconds * stepsKm.length);

  /// "3 km", "2.5 km", with a non-breaking space so it never wraps apart.
  static String label(double km) =>
      '${km == km.roundToDouble() ? km.round() : km}\u00A0km';
}

/// Steps of an accepted request, from the server's `status`.
enum TripStage {
  /// `driver_assigned` / `en_route_to_pickup`.
  toPickup,

  /// `arrive_at_pickup`.
  arrived,

  /// `en_route_to_hospital`.
  toHospital,
}

/// The ambulance serving the user's request, from the `driver`, `ambulance`,
/// `hospital` and `eta` objects of `GET /emergency-requests/{id}`.
///
/// Every field is optional so the tracking screen works with whatever the
/// server sends.
class TripInfo {
  const TripInfo({
    this.driverName,
    this.driverPhone,
    this.driverPhotoUrl,
    this.driverRating,
    this.driverTripCount,
    this.plateNumber,
    this.vehicleType,
    this.ambulanceLocation,
    this.locationAgeSeconds,
    this.hospitalName,
    this.hospitalLocation,
    this.hospitalPreparation,
    this.hospitalEntrance,
    this.etaMinutes,
    this.distanceKm,
    this.shareUrl,
  });

  final String? driverName;
  final String? driverPhone;
  final String? driverPhotoUrl;
  final double? driverRating;
  final int? driverTripCount;
  final String? plateNumber;

  /// e.g. "Ambulans ALS".
  final String? vehicleType;

  /// Live position of the ambulance.
  final LatLng? ambulanceLocation;

  /// How long ago the ambulance last reported that position (server clock).
  final int? locationAgeSeconds;

  /// The driver stopped reporting (phone off, no signal): the marker is
  /// stale, not moving.
  bool get driverSilent =>
      ambulanceLocation != null &&
      (locationAgeSeconds ?? 0) >= silentAfterSeconds;

  static const silentAfterSeconds = 40;
  final String? hospitalName;

  /// Where the ambulance takes the patient, once it has left the pickup.
  final LatLng? hospitalLocation;

  /// What the IGD is preparing, e.g. "IGD menyiapkan tim jantung."
  final String? hospitalPreparation;

  /// Where the ambulance pulls in, e.g. "Gerbang B".
  final String? hospitalEntrance;
  final int? etaMinutes;
  final double? distanceKm;

  /// Public page following the ambulance live, for "Bagikan lokasi live".
  final String? shareUrl;

  /// "ALS · Gawat Darurat" chip next to the plate.
  String? get vehicleLabel {
    final type = vehicleType;
    if (type == null) return null;
    if (type.contains('ALS')) return 'ALS · Gawat Darurat';
    if (type.contains('BLS')) return 'BLS · Dasar';
    return type;
  }
}

/// One of the user's past requests, for Riwayat.
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
  });

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

  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';
}

/// Someone the paramedics or hospital can call, e.g. "Suami — Andi Pratama".
class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.relation,
    required this.phone,
  });

  final String name;
  final String relation;
  final String phone;

  Map<String, dynamic> toJson() => {
    'name': name,
    'relation': relation,
    'phone': phone,
  };

  static EmergencyContact? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'] as String?;
    final phone = json['phone'] as String?;
    if (name == null || phone == null) return null;
    return EmergencyContact(
      name: name,
      relation: json['relation'] as String? ?? '',
      phone: phone,
    );
  }
}

/// The patient's Medical ID, shared with paramedics during an emergency.
class MedicalProfile {
  const MedicalProfile({
    this.bloodType,
    this.birthDate,
    this.weightKg,
    this.heightCm,
    this.allergies = const [],
    this.conditions = const [],
    this.emergencyContact,
    this.insurance,
    this.shareOnSos = true,
  });

  /// With rhesus, e.g. "O+". Null when unknown.
  final String? bloodType;
  final DateTime? birthDate;
  final int? weightKg;
  final int? heightCm;
  final List<String> allergies;

  /// Illnesses such as "Asma" or "Hipertensi".
  final List<String> conditions;
  final EmergencyContact? emergencyContact;

  /// e.g. "BPJS".
  final String? insurance;

  /// "Bagikan otomatis saat SOS".
  final bool shareOnSos;

  static const empty = MedicalProfile();

  int? get age {
    final birth = birthDate;
    if (birth == null) return null;
    final now = DateTime.now();
    var years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      years--;
    }
    return years;
  }

  /// Enough for paramedics to act on: blood type plus an emergency contact.
  bool get isComplete => bloodType != null && emergencyContact != null;

  MedicalProfile copyWith({
    String? Function()? bloodType,
    DateTime? Function()? birthDate,
    int? Function()? weightKg,
    int? Function()? heightCm,
    List<String>? allergies,
    List<String>? conditions,
    EmergencyContact? Function()? emergencyContact,
    String? Function()? insurance,
    bool? shareOnSos,
  }) => MedicalProfile(
    bloodType: bloodType == null ? this.bloodType : bloodType(),
    birthDate: birthDate == null ? this.birthDate : birthDate(),
    weightKg: weightKg == null ? this.weightKg : weightKg(),
    heightCm: heightCm == null ? this.heightCm : heightCm(),
    allergies: allergies ?? this.allergies,
    conditions: conditions ?? this.conditions,
    emergencyContact: emergencyContact == null
        ? this.emergencyContact
        : emergencyContact(),
    insurance: insurance == null ? this.insurance : insurance(),
    shareOnSos: shareOnSos ?? this.shareOnSos,
  );

  /// Same shape as `GET/PUT /me/medical-profile`.
  Map<String, dynamic> toJson() => {
    'blood_type': bloodType,
    'birth_date': birthDate?.toIso8601String().substring(0, 10),
    'weight_kg': weightKg,
    'height_cm': heightCm,
    'allergies': allergies,
    'medical_conditions': conditions,
    // The API stores the contact as three flat columns; null clears them.
    'emergency_contact_name': emergencyContact?.name,
    'emergency_contact_relation': emergencyContact?.relation,
    'emergency_contact_phone': emergencyContact?.phone,
    'insurance': insurance,
    'share_on_sos': shareOnSos,
  };

  factory MedicalProfile.fromJson(Map<String, dynamic> json) => MedicalProfile(
    bloodType: json['blood_type'] as String?,
    birthDate: DateTime.tryParse(json['birth_date'] as String? ?? ''),
    weightKg: (json['weight_kg'] as num?)?.toInt(),
    heightCm: (json['height_cm'] as num?)?.toInt(),
    allergies: _strings(json['allergies']),
    conditions: _strings(json['medical_conditions']),
    emergencyContact: EmergencyContact.fromJson(
      // Copies saved on the phone by older versions nest the contact.
      json['emergency_contact'] ??
          {
            'name': json['emergency_contact_name'],
            'relation': json['emergency_contact_relation'],
            'phone': json['emergency_contact_phone'],
          },
    ),
    insurance: json['insurance'] as String?,
    shareOnSos: json['share_on_sos'] as bool? ?? true,
  );

  /// Accepts a list or the comma-separated text the old columns hold.
  static List<String> _strings(Object? value) => switch (value) {
    final List<dynamic> list => [for (final v in list) '$v'],
    final String text =>
      text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
    _ => const [],
  };
}

/// A pickup address the user saved, e.g. "Rumah".
class SavedAddress {
  const SavedAddress({
    required this.label,
    required this.address,
    required this.location,
    this.id,
  });

  /// Null until the server has stored it.
  final String? id;
  final String label;
  final String address;
  final LatLng location;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'address': address,
    'latitude': location.latitude,
    'longitude': location.longitude,
  };

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
    id: json['id'] as String?,
    label: json['label'] as String,
    address: json['address'] as String,
    location: LatLng(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    ),
  );
}
