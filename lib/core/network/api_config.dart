abstract final class ApiConfig {
  static const _envUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    return 'http://10.0.2.2:8080';
  }

  static const timeout = Duration(seconds: 15);
}
