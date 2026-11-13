/// Where the CariAmbulan Laravel API lives.
///
/// Defaults to the shared team server over HTTPS on port 443, the one port
/// campus and office networks reliably let through (8080/8081/7880 are often
/// blocked). Override per build for a local server,
/// e.g. `--dart-define=API_BASE_URL=http://10.0.2.2:8080` on the Android
/// emulator (10.0.2.2 is the host machine) or `http://127.0.0.1:8080` on the
/// iOS simulator.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://103-150-60-58.sslip.io',
  );

  static const reverbKey = String.fromEnvironment(
    'REVERB_KEY',
    defaultValue: 'cariambulan-key',
  );

  static const reverbPort = int.fromEnvironment(
    'REVERB_PORT',
    defaultValue: 8443,
  );

  /// WebSocket host derived from baseUrl or explicitly overridden.
  static String get reverbHost {
    const override = String.fromEnvironment('REVERB_HOST');
    if (override.isNotEmpty) return override;
    try {
      final uri = Uri.parse(baseUrl);
      return uri.host.isNotEmpty ? uri.host : '103-150-60-58.sslip.io';
    } catch (_) {
      return '103-150-60-58.sslip.io';
    }
  }

  static const livekitUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'wss://ambulan-97m25hmt.livekit.cloud',
  );

  static const timeout = Duration(seconds: 15);
}
