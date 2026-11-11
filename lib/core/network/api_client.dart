import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../logging/app_log.dart';
import 'api_config.dart';

/// A failed API call, with a message that can be shown to the user.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.body});

  final String message;

  /// The error response, for fields beyond the message.
  final Map<String, dynamic>? body;

  /// Null when the server couldn't be reached.
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin JSON client for the Laravel API (`/api/v1`), sending the Sanctum
/// bearer token when signed in.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  String? token;

  /// Called when the server rejects the token, so the app can sign out.
  void Function()? onUnauthorized;

  final _lastGet = <String, int>{};
  final _hiddenGets = <String, int>{};

  Future<Map<String, dynamic>?> get(
    String path, {
    Map<String, String>? query,
  }) =>
      _send('GET', path, query: query);

  Future<Map<String, dynamic>?> post(String path, [Object? body]) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>?> put(String path, [Object? body]) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>?> delete(String path) =>
      _send('DELETE', path);

  Future<Map<String, dynamic>?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final cleanBase = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final uri = Uri.parse('$cleanBase/api/v1/$path').replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);

    final call = '$method ${uri.path.replaceFirst('/api/v1/', '')}${uri.hasQuery ? '?${uri.query}' : ''}';
    if (body != null) AppLog.debug('API', '$call ${_redact(body)}');
    final watch = Stopwatch()..start();

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(ApiConfig.timeout),
      );
    } on TimeoutException {
      AppLog.warn('API', '$call → timeout after ${watch.elapsedMilliseconds} ms');
      throw const ApiException('Server tidak merespons. Coba lagi.');
    } on SocketException catch (e) {
      AppLog.warn('API', '$call → no connection', e.message);
      throw const ApiException('Tidak dapat terhubung ke server. Periksa koneksi Anda.');
    } on http.ClientException catch (e) {
      AppLog.warn('API', '$call → no connection', e.message);
      throw const ApiException('Tidak dapat terhubung ke server. Periksa koneksi Anda.');
    }

    final json = response.body.isEmpty
        ? null
        : jsonDecode(response.body) as Map<String, dynamic>;
    final ms = watch.elapsedMilliseconds;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _logSuccess(method, call, response, json, ms);
      return json;
    }

    if (response.statusCode == 401) onUnauthorized?.call();

    final message = response.statusCode >= 500
        ? 'Server sedang bermasalah (${response.statusCode}). Coba lagi.'
        : _errorMessage(json);
    final error = message ?? 'Terjadi kesalahan (${response.statusCode}).';
    final line = '$call → ${response.statusCode} · $ms ms · $error';
    if (response.statusCode >= 500) {
      AppLog.error('API', line);
    } else {
      AppLog.warn('API', line);
    }
    throw ApiException(error, statusCode: response.statusCode, body: json);
  }

  void _logSuccess(
    String method,
    String call,
    http.Response response,
    Map<String, dynamic>? json,
    int ms,
  ) {
    final line = '$call → ${response.statusCode} · $ms ms${_summary(json)}';
    if (method != 'GET') {
      AppLog.info('API', line);
      return;
    }
    final hash = response.body.hashCode;
    if (_lastGet[call] == hash) {
      _hiddenGets[call] = (_hiddenGets[call] ?? 0) + 1;
      AppLog.debug('API', '$line (unchanged)');
      return;
    }
    _lastGet[call] = hash;
    final hidden = _hiddenGets.remove(call);
    AppLog.info('API', hidden == null ? line : '$line (after $hidden unchanged polls)');
  }

  static String _summary(Map<String, dynamic>? json) {
    final data = json?['data'];
    if (data is List) return ' · ${data.length} items';
    if (data is! Map) return data == null && json != null ? ' · null' : '';
    final status = data['status'];
    return status == null ? '' : ' · status=$status';
  }

  static String _redact(Object body) {
    if (body is! Map) return jsonEncode(body);
    return jsonEncode({
      for (final MapEntry(:key, :value) in body.entries)
        key: '$key'.contains('password') || '$key'.contains('token')
            ? '***'
            : value,
    });
  }

  String? _errorMessage(Map<String, dynamic>? json) {
    final errors = json?['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    return json?['message'] as String?;
  }
}

