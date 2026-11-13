import '../../../core/constants/user_role.dart';

/// The signed-in account, from `GET /auth/me`.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.roles,
    this.email,
    this.phone,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    fullName: json['full_name'] as String,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    roles: (json['roles'] as List).cast<String>(),
  );

  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final List<String> roles;

  /// Saved with the token, so the app opens before `auth/me` answers.
  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'phone': phone,
    'roles': roles,
  };

  bool get isDriver => roles.contains('driver');

  /// A patient or caller using the user app.
  bool get isUser => roles.contains('user');
}

/// Fields accepted by the mobile registration endpoint.
class RegistrationData {
  const RegistrationData({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
    required this.passwordConfirmation,
    required this.role,
    this.licenseNumber,
    this.plateNumber,
    this.vehicleType,
  });

  final String fullName;
  final String email;
  final String phone;
  final String password;
  final String passwordConfirmation;
  final UserRole role;
  final String? licenseNumber;
  final String? plateNumber;
  final String? vehicleType;

  Map<String, dynamic> toJson() => {
    'full_name': fullName.trim(),
    'email': email.trim(),
    'phone': phone.trim(),
    'password': password,
    'password_confirmation': passwordConfirmation,
    'role': role.apiValue,
    if (role.isDriver) ...{
      if (licenseNumber != null && licenseNumber!.trim().isNotEmpty)
        'license_number': licenseNumber!.trim(),
      if (plateNumber != null && plateNumber!.trim().isNotEmpty)
        'plate_number': plateNumber!.trim(),
      if (vehicleType != null && vehicleType!.trim().isNotEmpty)
        'vehicle_type': vehicleType!.trim(),
    },
  };
}
