/// An exception handler of your own, for an API that calls other services:
///
/// - A `TimeoutException` of a call to another service is a 504, and a `SocketException` a 502,
///   instead of the generic 500 of an unexpected error (they're not bugs of this server).
/// - The unexpected errors go to an error tracker (Sentry, Rollbar...) with the request id, so a
///   user who reports the id of their 500 can be found.
/// - A legacy endpoint answers its errors in its old format with a `ResponseException`.
///
/// Run: `dart run lib/custom_handler.dart`, then `curl -i localhost:8080/weather`
library;

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:winter/winter.dart';

/// Stands for the client of an error tracker
class ErrorTracker {
  final List<String> reported = [];

  void report(Object error, {required String? requestId}) =>
      reported.add('${error.runtimeType} ($requestId)');
}

class GatewayExceptionHandler extends SimpleExceptionHandler {
  GatewayExceptionHandler(ErrorTracker tracker)
    : super(
        logUnhandledError: (request, error, stackTrace) {
          logger.error(
            'Unhandled error in ${request.method} ${request.requestedUri.path}',
            error: error,
            stackTrace: stackTrace,
          );
          tracker.report(error, requestId: requestId);
        },
      );

  @override
  Future<ResponseEntity> handle(
    RequestEntity request,
    Object error,
    StackTrace stackTrace,
  ) {
    // Answered as another error: the default rules format it as a Problem Details
    final Object answered = switch (error) {
      TimeoutException() => const ApiException(
        StatusCode.gatewayTimeout,
        detail: 'The weather service did not answer in time',
      ),
      SocketException() => const ApiException(
        StatusCode.badGateway,
        detail: 'The weather service is unreachable',
      ),
      _ => error,
    };
    return super.handle(request, answered, stackTrace);
  }
}

WinterRouter router(Future<double> Function() fetchTemperature) => WinterRouter(
  routes: [
    Route.get(
      path: '/weather',
      handler: (request) async => ResponseEntity.ok(
        body: {
          'temperature': await fetchTemperature().timeout(
            const Duration(seconds: 2),
          ),
        },
      ),
    ),
    // An old endpoint whose clients expect {"error": "..."}: a ResponseException is sent as is
    Route.get(
      path: '/legacy/weather',
      handler: (request) => throw ResponseException(
        ResponseEntity(410, body: {'error': 'Use /weather'}),
      ),
    ),
  ],
);

Future<void> main() async {
  Winter.context.setUp(
    exceptionHandler: GatewayExceptionHandler(ErrorTracker()),
  );
  await Winter.start(router: router(() async => 21.5));
}
