import 'package:flutter/foundation.dart';

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

abstract final class AppLog {
  static const _tagWidth = 8;
  static const _reset = '\x1B[0m';
  static const _dim = '\x1B[90m';

  static final LogLevel minLevel = LogLevel.values.firstWhere(
    (l) => l.name == const String.fromEnvironment('LOG_LEVEL', defaultValue: ''),
    orElse: () => LogLevel.info,
  );

  static const _color = bool.fromEnvironment('LOG_COLOR', defaultValue: true);

  @visibleForTesting
  static void Function(String line) output = debugPrint;

  static void debug(String tag, String message) => _log(LogLevel.debug, tag, message);
  static void info(String tag, String message) => _log(LogLevel.info, tag, message);
  static void warn(String tag, String message, [Object? error]) => _log(LogLevel.warn, tag, message, error);
  static void error(String tag, String message, [Object? error, StackTrace? stack]) => _log(LogLevel.error, tag, message, error, stack);

  static void _log(LogLevel level, String tag, String message, [Object? error, StackTrace? stack]) {
    if (kReleaseMode || level.index < minLevel.index) return;

    final now = DateTime.now();
    final time = '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';
    final paddedTag = tag.padRight(_tagWidth).substring(0, _tagWidth);
    final errStr = error != null ? ' ($error)' : '';

    if (_color) {
      output('$_dim$time$_reset ${level.color}${level.icon} ${level.label}$_reset $paddedTag $_dim│$_reset $message$errStr');
    } else {
      output('$time ${level.icon} ${level.label} $paddedTag │ $message$errStr');
    }

    if (stack != null) {
      output(stack.toString());
    }
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

