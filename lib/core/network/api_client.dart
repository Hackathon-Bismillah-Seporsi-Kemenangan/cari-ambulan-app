import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../logging/app_log.dart';
import 'api_config.dart';

/// A failed API call, with a message that can be shown to the driver.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.body});

  final String message;

  /// The server's JSON error body, for the few errors that carry data.
  final Map<String, dynamic>? body;

  /// Null when the server couldn't be reached.
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  /// The order changed under us (taken, expired, wrong step).
  bool get isConflict => statusCode == 409;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin JSON client for the Laravel API (`/api/v1`), sending the Sanctum
/// bearer token when signed in.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? _newClient(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  /// One long-lived client so requests reuse an open connection. A new
  /// connection is the slow part on a lossy network (a lost SYN costs 1-7 s);
  /// a reused one skips it. The short connect timeout gives up on a lost SYN
  /// quickly so the retry can open a fresh one.
  static http.Client _newClient() => IOClient(
    HttpClient()
      ..connectionTimeout = const Duration(seconds: 4)
      ..idleTimeout = const Duration(seconds: 90)
      ..maxConnectionsPerHost = 6,
  );

  /// A GET is safe to repeat, so it gets a tighter timeout and one retry.
  static const _getTimeout = Duration(seconds: 6);
  static const _retryStatuses = {502, 503, 504};

  final http.Client _client;
  final String _baseUrl;

  String? token;

  /// Called when the server rejects the token, so the app can sign out.
  void Function()? onUnauthorized;

  /// A request can be sent only once, so each attempt needs its own copy.
  static http.Request _copy(http.Request r) => http.Request(r.method, r.url)
    ..headers.addAll(r.headers)
    ..bodyBytes = r.bodyBytes;

  /// Last response body per polled GET, so a poll that returns the same
  /// thing every 3 s doesn't flood the log.
  final _lastGet = <String, int>{};
  final _hiddenGets = <String, int>{};

  Future<Map<String, dynamic>?> get(
    String path, {
    Map<String, String>? query,
  }) => _send('GET', path, query: query);

  Future<Map<String, dynamic>?> post(String path, [Object? body]) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>?> put(String path, [Object? body]) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/v1/$path',
    ).replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);

    final call =
        '$method ${uri.path.replaceFirst('/api/v1/', '')}'
        '${uri.hasQuery ? '?${uri.query}' : ''}';
    if (body != null) AppLog.debug('API', '$call ${_redact(body)}');
    final watch = Stopwatch()..start();

    final isGet = method == 'GET';
    final timeout = isGet ? _getTimeout : ApiConfig.timeout;
    final attempts = isGet ? 2 : 1;
    http.Response? response;
    Object? failure;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final r = await http.Response.fromStream(
          await _client.send(_copy(request)).timeout(timeout),
        );
        if (isGet && attempt < attempts && _retryStatuses.contains(r.statusCode)) {
          AppLog.warn('API', '$call → ${r.statusCode}, retrying');
          await Future<void>.delayed(const Duration(milliseconds: 250));
          continue;
        }
        response = r;
        break;
      } on TimeoutException catch (e) {
        failure = e;
        AppLog.warn(
          'API',
          '$call → timeout after ${watch.elapsedMilliseconds} ms'
          '${attempt < attempts ? ', retrying' : ''}',
        );
      } on SocketException catch (e) {
        failure = e;
        AppLog.warn('API', '$call → no connection', e.message);
      } on http.ClientException catch (e) {
        failure = e;
        AppLog.warn('API', '$call → no connection', e.message);
      }
      if (attempt < attempts) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    if (response == null) {
      throw failure is TimeoutException
          ? const ApiException('Server tidak merespons. Coba lagi.')
          : const ApiException(
              'Tidak dapat terhubung ke server. Periksa koneksi Anda.',
            );
    }

    // A proxy or captive portal can answer with HTML instead of our JSON.
    Map<String, dynamic>? json;
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        json = decoded is Map<String, dynamic> ? decoded : null;
      } on FormatException {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          throw const ApiException(
            'Respons server tidak dikenali. Jaringan Anda mungkin memblokir '
            'akses. Coba jaringan lain.',
          );
        }
      }
    }
    final ms = watch.elapsedMilliseconds;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _logSuccess(method, call, response, json, ms);
      return json;
    }

    if (response.statusCode == 401) onUnauthorized?.call();
    // A 5xx message is a server internal (e.g. a SQL error in debug mode),
    // not something to show the user.
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
    AppLog.info(
      'API',
      hidden == null ? line : '$line  (after $hidden unchanged polls)',
    );
  }

  /// " · status=driver_assigned", the part of a response worth seeing.
  static String _summary(Map<String, dynamic>? json) {
    final data = json?['data'];
    if (data is List) return ' · ${data.length} items';
    if (data is! Map) return data == null && json != null ? ' · null' : '';
    final status = data['status'];
    return status == null ? '' : ' · status=$status';
  }

  /// Request body for the debug log, without passwords or tokens.
  static String _redact(Object body) {
    if (body is! Map) return jsonEncode(body);
    return jsonEncode({
      for (final MapEntry(:key, :value) in body.entries)
        key: '$key'.contains('password') || '$key'.contains('token')
            ? '***'
            : value,
    });
  }

  /// Laravel puts the first validation error under `errors`, others under
  /// `message`.
  String? _errorMessage(Map<String, dynamic>? json) {
    final errors = json?['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    return json?['message'] as String?;
  }
}
