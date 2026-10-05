import 'dart:io';

/// Levels of a log, from the most verbose to the most important.
enum LogLevel { debug, info, warning, error }

/// Every log of the framework goes through a [WinterLogger], so they can be
/// filtered by level or sent anywhere (a file, a logging service...) by
/// replacing it in the `BuildContext`:
///
/// ```dart
/// Winter.context.setUp(logger: ConsoleLogger(minLevel: LogLevel.warning));
/// ```
abstract class WinterLogger {
  const WinterLogger();

  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  });

  void debug(String message) => log(LogLevel.debug, message);

  void info(String message) => log(LogLevel.info, message);

  void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.warning, message, error: error, stackTrace: stackTrace);

  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.error, message, error: error, stackTrace: stackTrace);
}

/// Default logger: debug & info to stdout, warning & error to stderr.
/// Logs below [minLevel] are ignored.
class ConsoleLogger extends WinterLogger {
  final LogLevel minLevel;

  const ConsoleLogger({this.minLevel = LogLevel.info});

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;

    final IOSink output = level.index >= LogLevel.warning.index
        ? stderr
        : stdout;
    output.writeln(
      '${DateTime.now().toIso8601String()} [${level.name.toUpperCase()}] $message',
    );
    if (error != null) output.writeln(error);
    if (stackTrace != null) output.writeln(stackTrace);
  }
}
