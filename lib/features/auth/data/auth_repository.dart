import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../domain/auth_models.dart';

/// Token login against the Laravel API. The token is kept in the platform
/// keystore so the user stays signed in across restarts.
class AuthRepository {
  AuthRepository(this._client, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final ApiClient _client;
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  /// The account saved at the last sign-in, read without the network; null
  /// when signed out or saved by an older app version.
  /// [restoreSession] should still confirm it.
  Future<AuthUser?> savedSession() async {
    final (token, saved) = await (
      _storage.read(key: _tokenKey),
      _storage.read(key: _userKey),
    ).wait;
    if (token == null || saved == null) return null;
    try {
      final user = AuthUser.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      _client.token = token;
      return user;
    } on Object {
      return null;
    }
  }

  /// Keeps the saved account in step, e.g. after Profil edits the name.
  Future<void> saveUser(AuthUser user) =>
      _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

  /// The saved session, or null when signed out or the token was revoked.
  Future<AuthUser?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return null;

    _client.token = token;
    try {
      final json = await _client.get('auth/me');
      final user = AuthUser.fromJson(json!['data'] as Map<String, dynamic>);
      await saveUser(user);
      return user;
    } on ApiException catch (e) {
      if (!e.isUnauthorized) rethrow;
      await _clearToken();
      return null;
    }
  }

  Future<AuthUser> login(String email, String password) async {
    final json = await _client.post('auth/login', {
      'email': email,
      'password': password,
      'device_name': 'medicgo-app',
    });
    return _saveSession(json!);
  }

  Future<AuthUser> register(RegistrationData data) async {
    final json = await _client.post('auth/register', {
      ...data.toJson(),
      'device_name': 'medicgo-app',
    });
    return _saveSession(json!);
  }

  Future<AuthUser> _saveSession(Map<String, dynamic> json) async {
    final user = AuthUser.fromJson(json['user'] as Map<String, dynamic>);
    final token = json['token'] as String;
    await _storage.write(key: _tokenKey, value: token);
    await saveUser(user);
    _client.token = token;
    return user;
  }

  Future<void> logout() async {
    try {
      await _client.post('auth/logout');
    } on ApiException {
      // Signing out locally is enough if the server can't be reached.
    }
    await _clearToken();
  }

  Future<void> _clearToken() async {
    _client.token = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}
