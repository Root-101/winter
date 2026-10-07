import 'dart:convert';
import 'dart:io';

import 'package:winter/winter.dart';

/// Levels of a log, from the most verbose to the most important.
enum LogLevel { debug, info, warning, error }

/// Every log of the framework goes through a [WinterLogger], so they can be
/// filtered by level or sent anywhere (a file, a logging service...) by
/// replacing it in the `BuildContext`:
///
/// ```dart
/// Winter.context.setUp(logger: const JsonLogger()); // production: one JSON per line
/// logger.info('Order created', fields: {'orderId': 42});
/// ```
///
/// Every level takes an [Object] error, its [StackTrace] and [fields] (structured data). Never
/// log the body of a request, a token or a password.
abstract class WinterLogger {
  const WinterLogger();

  /// Writes a log of [level]. A logger of its own implements only this (and [isEnabled]).
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  });

  /// Whether a log of [level] is written: check it before building an expensive message.
  bool isEnabled(LogLevel level) => true;

  /// A log of [LogLevel.debug]
  void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) => log(
    LogLevel.debug,
    message,
    error: error,
    stackTrace: stackTrace,
    fields: fields,
  );

  /// A log of [LogLevel.info]
  void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) => log(
    LogLevel.info,
    message,
    error: error,
    stackTrace: stackTrace,
    fields: fields,
  );

  /// A log of [LogLevel.warning]
  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) => log(
    LogLevel.warning,
    message,
    error: error,
    stackTrace: stackTrace,
    fields: fields,
  );

  /// A log of [LogLevel.error]
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) => log(
    LogLevel.error,
    message,
    error: error,
    stackTrace: stackTrace,
    fields: fields,
  );
}

/// The default logger, for development: one readable line per log, the time in UTC.
///
/// ```text
/// 2026-10-07T16:11:07.171Z [INFO] [8f1c...] Order created orderId=42
/// ```
///
/// The request id is there inside a request. Debug and info go to stdout, warning and error to
/// stderr, with the error and the stack trace in the next lines. Logs below [minLevel] are ignored.
class ConsoleLogger extends WinterLogger {
  /// The lowest level written
  final LogLevel minLevel;

  /// A logger that writes from [minLevel] up
  const ConsoleLogger({this.minLevel = LogLevel.info});

  @override
  bool isEnabled(LogLevel level) => level.index >= minLevel.index;

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) {
    if (!isEnabled(level)) return;

    final IOSink output = level.index >= LogLevel.warning.index
        ? stderr
        : stdout;
    final String? id = requestId;
    final String extra = [
      for (final MapEntry(:key, :value) in fields.entries) '$key=$value',
    ].join(' ');
    output.writeln(
      '${DateTime.now().toUtc().toIso8601String()} '
      '[${level.name.toUpperCase()}] '
      '${id == null ? '' : '[$id] '}'
      '$message${extra.isEmpty ? '' : ' $extra'}',
    );
    if (error != null) output.writeln(error);
    if (stackTrace != null) output.writeln(stackTrace);
  }
}

/// A logger for production: one JSON object per line on stdout, with the keys that Cloud Logging
/// reads by itself and that Datadog or Loki map easily:
///
/// ```json
/// {"time":"2026-10-07T16:11:07.171Z","severity":"INFO","message":"Order created","requestId":"8f1c...","orderId":42}
/// ```
///
/// `requestId` is there inside a request, `error` and `stackTrace` (as strings) when given, and the
/// [fields] are members of their own (they never replace the keys above). A field that is not a
/// JSON value is written as its text. Logs below [minLevel] are ignored.
class JsonLogger extends WinterLogger {
  /// The lowest level written
  final LogLevel minLevel;

  /// A logger that writes from [minLevel] up
  const JsonLogger({this.minLevel = LogLevel.info});

  @override
  bool isEnabled(LogLevel level) => level.index >= minLevel.index;

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) {
    if (!isEnabled(level)) return;
    stdout.writeln(
      jsonEncode({
        ...fields,
        'time': DateTime.now().toUtc().toIso8601String(),
        'severity': level.name.toUpperCase(),
        'message': message,
        'requestId': ?requestId,
        if (error != null) 'error': '$error',
        if (stackTrace != null) 'stackTrace': '$stackTrace',
      }, toEncodable: (value) => '$value'),
    );
  }
}
