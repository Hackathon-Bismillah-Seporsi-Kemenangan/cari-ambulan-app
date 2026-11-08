/// Enum to represent the user's chosen role in the app.
enum UserRole {
  patient,
  driver;

  bool get isPatient => this == UserRole.patient;
  bool get isDriver => this == UserRole.driver;

  String get label => isPatient ? 'Pasien / Keluarga' : 'Driver Ambulans';

  /// The API calls the patient/caller role `user`.
  String get apiValue => isPatient ? 'user' : 'driver';
}

