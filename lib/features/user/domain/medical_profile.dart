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
}

/// The patient's Medical ID, shared with the driver and hospital during an
/// emergency, from `GET /me/medical-profile`.
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

  /// Body of `PUT /me/medical-profile`.
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

  factory MedicalProfile.fromJson(Map<String, dynamic> json) {
    final contactName = json['emergency_contact_name'] as String?;
    final contactPhone = json['emergency_contact_phone'] as String?;
    final bloodType = json['blood_type'] as String?;

    return MedicalProfile(
      bloodType: bloodType == 'unknown' ? null : bloodType,
      birthDate: DateTime.tryParse(json['birth_date'] as String? ?? ''),
      weightKg: (json['weight_kg'] as num?)?.toInt(),
      heightCm: (json['height_cm'] as num?)?.toInt(),
      allergies: _strings(json['allergies']),
      conditions: _strings(json['medical_conditions']),
      emergencyContact: contactName == null || contactPhone == null
          ? null
          : EmergencyContact(
              name: contactName,
              relation: json['emergency_contact_relation'] as String? ?? '',
              phone: contactPhone,
            ),
      insurance: json['insurance'] as String?,
      shareOnSos: json['share_on_sos'] as bool? ?? true,
    );
  }

  /// Accepts a list or the comma-separated text older rows hold.
  static List<String> _strings(Object? value) => switch (value) {
    final List<dynamic> list => [for (final v in list) '$v'],
    final String text =>
      text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
    _ => const [],
  };
}
