import 'package:flutter/foundation.dart';

/// How much [AppLog] prints. Pick with
/// `flutter run --dart-define=LOG_LEVEL=debug` (default `info`).
enum LogLevel {
  debug('·', 'DEBUG', '\x1B[90m'),
  info('✓', 'INFO ', '\x1B[32m'),
  warn('!', 'WARN ', '\x1B[33m'),
  error('✗', 'ERROR', '\x1B[31m');

  const LogLevel(this.icon, this.label, this.color);

  final String icon;
  final String label;
  final String color;
}

/// One-line, aligned, colored logs for the terminal during `flutter run`:
///
/// ```
/// 14:02:07 ✓ INFO  API      │ GET emergency-requests/current → 200 · 142 ms
/// 14:02:09 ! WARN  Route    │ router.project-osrm.org: HTTP 429
/// ```
///
/// Prints in debug and profile builds only. Colors can be turned off with
/// `--dart-define=LOG_COLOR=false` (e.g. when the terminal shows `[32m`).
abstract final class AppLog {
  static const _tagWidth = 8;
  static const _reset = '\x1B[0m';
  static const _dim = '\x1B[90m';

  static final LogLevel minLevel = LogLevel.values.firstWhere(
    (l) =>
        l.name == const String.fromEnvironment('LOG_LEVEL', defaultValue: ''),
    orElse: () => LogLevel.info,
  );

  static const _color = bool.fromEnvironment('LOG_COLOR', defaultValue: true);

  /// Replaced in tests to capture lines.
  @visibleForTesting
  static void Function(String line) output = debugPrint;

  static void debug(String tag, String message) =>
      _log(LogLevel.debug, tag, message);

  static void info(String tag, String message) =>
      _log(LogLevel.info, tag, message);

  static void warn(String tag, String message, [Object? error]) =>
      _log(LogLevel.warn, tag, message, error);

  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) => _log(LogLevel.error, tag, message, error, stack);

  static void _log(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    if (kReleaseMode || level.index < minLevel.index) return;

    final now = DateTime.now();
    final time = [
      now.hour,
      now.minute,
      now.second,
    ].map((n) => n.toString().padLeft(2, '0')).join(':');
    final name = tag.length > _tagWidth
        ? tag.substring(0, _tagWidth)
        : tag.padRight(_tagWidth);
    final text = error == null ? message : '$message: ${_describe(error)}';

    final line = _color
        ? '$_dim$time$_reset ${level.color}${level.icon} ${level.label} '
              '$name$_reset $_dim│$_reset $text'
        : '$time ${level.icon} ${level.label} $name │ $text';
    output(line);
    if (stack != null) output(stack.toString());
  }

  /// Exceptions' toString often starts with the class name only, e.g.
  /// "ApiException(404): Not found." — keep it, but on one line.
  static String _describe(Object error) =>
      error.toString().replaceAll('\n', ' ').trim();
}
