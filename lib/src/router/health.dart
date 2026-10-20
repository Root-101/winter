import 'dart:async';

import 'package:winter/winter.dart';

/// A check of something the app needs (the database, a queue), for [Route.health]: true when it
/// works. Returning false, throwing or taking longer than the timeout of the route is a failure.
///
/// {@category Routing}
typedef HealthCheck = FutureOr<bool> Function();

/// The handler of [Route.health]: every check of [checks] at once, each one limited to [timeout].
/// Internal.
///
/// The format of the draft *Health Check Response Format for HTTP APIs*
/// (`application/health+json`): a 200 `{"status": "pass", "checks": {"database": [{"status":
/// "pass"}]}}` when all of them pass, and a 503 with `"status": "fail"` otherwise. The reason of a
/// failure is logged, never sent.
///
/// {@category Routing}
RequestHandler healthHandler(
  Map<String, HealthCheck> checks,
  Duration timeout,
) {
  if (timeout <= Duration.zero) {
    throw ArgumentError.value(timeout, 'timeout', 'Must be more than 0');
  }
  final Map<String, HealthCheck> copy = Map.unmodifiable(checks);
  return (request) async {
    final List<bool> results = await Future.wait([
      for (final MapEntry<String, HealthCheck> check in copy.entries)
        _run(check.key, check.value, timeout),
    ]);
    final bool up = results.every((result) => result);
    final List<String> names = copy.keys.toList();
    return ResponseEntity<Map<String, Object>>(
      up ? StatusCode.ok.value : StatusCode.serviceUnavailable.value,
      body: {
        'status': _status(up),
        if (names.isNotEmpty)
          'checks': {
            // A list per component: the draft allows several measurements of one
            for (int i = 0; i < names.length; i++)
              names[i]: [
                {'status': _status(results[i])},
              ],
          },
      },
      headers: {
        // Not a Problem Details: the format of a health check is its own, also when it's a 503
        HttpHeader.contentType:
            '${MediaType.applicationHealthJson.mimeType}; charset=utf-8',
        HttpHeader.cacheControl: 'no-store',
      },
    );
  };
}

String _status(bool up) => up ? 'pass' : 'fail';

Future<bool> _run(String name, HealthCheck check, Duration timeout) async {
  try {
    final bool up = await Future<bool>.sync(check).timeout(timeout);
    if (!up) logger.warning('The health check $name is down');
    return up;
  } on TimeoutException {
    logger.warning('The health check $name took more than $timeout');
    return false;
  } catch (error, stackTrace) {
    logger.warning(
      'The health check $name failed',
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  }
}
