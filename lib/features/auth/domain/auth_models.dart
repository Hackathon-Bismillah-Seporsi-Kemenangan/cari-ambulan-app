class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.roles,
    this.email,
    this.phone,
    this.alamat,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        fullName: (json['full_name'] ?? json['name'] ?? '') as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        alamat: json['alamat'] as String?,
        roles: (json['roles'] as List? ?? []).map((e) => e.toString()).toList(),
      );

  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String? alamat;
  final List<String> roles;

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'alamat': alamat,
        'roles': roles,
      };

  bool get isDriver => roles.contains('driver');
  bool get isUser => roles.contains('user');
}

class RegistrationData {
  const RegistrationData({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
    required this.passwordConfirmation,
    required this.role,
    this.alamat,
  });

  final String fullName;
  final String email;
  final String phone;
  final String password;
  final String passwordConfirmation;
  final String role;
  final String? alamat;

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'alamat': alamat ?? '-',
        'password': password,
        'password_confirmation': passwordConfirmation,
        'role': role,
      };
}

