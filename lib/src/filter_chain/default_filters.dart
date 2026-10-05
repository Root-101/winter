import 'dart:async';

import 'package:winter/winter.dart';

/// Log the method & path of the request.
/// The query params are not logged, they may contain sensitive data (tokens, emails...).
void defaultLogRequest(RequestEntity request) {
  logger.info('REQUEST: ${request.method} ${request.requestedUri.path}');
}

/// Log the status code of the response and how long it took.
/// The body is not logged: it may contain sensitive data (tokens, personal data...) and be huge.
void defaultLogResponse(
  RequestEntity request,
  ResponseEntity response,
  Duration duration,
) {
  logger.info(
    'RESPONSE: ${request.method} ${request.requestedUri.path} => ${response.statusCode} (${duration.inMilliseconds} ms)',
  );
}

class LogsFilter extends Filter {
  final void Function(RequestEntity request) logRequest;

  /// Called with every response, including the error ones: the exceptions are converted
  /// into a response inside the filter chain, so this filter never receives an exception.
  final void Function(
    RequestEntity request,
    ResponseEntity response,
    Duration duration,
  )
  logResponse;

  LogsFilter({
    void Function(RequestEntity request)? logRequest,
    void Function(
      RequestEntity request,
      ResponseEntity response,
      Duration duration,
    )?
    logResponse,
    super.order,
  }) : logRequest = logRequest ?? defaultLogRequest,
       logResponse = logResponse ?? defaultLogResponse;

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    logRequest(request);

    final stopwatch = Stopwatch()..start();
    ResponseEntity response = await chain.doFilter(request);
    logResponse(request, response, stopwatch.elapsed);
    return response;
  }
}
