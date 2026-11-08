import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../domain/auth_models.dart';

/// Token login against the Laravel API. The token is kept in secure storage
/// so the user stays signed in across restarts.
class AuthRepository {
  AuthRepository(this._client, {FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final ApiClient _client;
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  /// Read the saved account from secure storage without network hit.
  Future<AuthUser?> savedSession() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final saved = await _storage.read(key: _userKey);
      if (token == null || saved == null) return null;
      final user = AuthUser.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      _client.token = token;
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(AuthUser user) =>
      _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

  /// Confirm session with GET /auth/me
  Future<AuthUser?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return null;

    _client.token = token;
    try {
      final json = await _client.get('auth/me');
      final data = json?['data'] as Map<String, dynamic>? ?? json;
      if (data == null) return null;
      final user = AuthUser.fromJson(data);
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
      'device_name': 'cariambulan-app',
    });
    return _saveSession(json!);
  }

  Future<AuthUser> register(RegistrationData data) async {
    final json = await _client.post('auth/register', {
      ...data.toJson(),
      'device_name': 'cariambulan-app',
    });
    return _saveSession(json!);
  }

  Future<AuthUser> _saveSession(Map<String, dynamic> json) async {
    final rawUser = json['user'] ?? json['data'];
    final user = AuthUser.fromJson(rawUser as Map<String, dynamic>);
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
      // Offline logout
    }
    await _clearToken();
  }

  Future<void> _clearToken() async {
    _client.token = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}

